# ============================================
# DNS & Access URLs
# ============================================

output "domain_name" {
  description = "Full domain name for accessing the server"
  value       = local.domain_name
}

output "dev_server_url" {
  description = "HTTPS URL for accessing the dev server"
  value       = "https://${local.domain_name}"
}

output "vscode_url" {
  description = "VS Code Server URL"
  value       = "https://${local.domain_name}/vscode"
}

output "claude_ui_url" {
  description = "Claude Code UI URL"
  value       = "https://${local.domain_name}"
}

# ============================================
# ALB Information
# ============================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

# ============================================
# EC2 Instance Information
# ============================================

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.dev_server.id
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.dev_server.private_ip
}

output "ec2_instance_profile" {
  description = "IAM instance profile attached to EC2"
  value       = aws_iam_instance_profile.ec2.name
}

# ============================================
# SSM Session Manager
# ============================================

output "ssm_start_session_command" {
  description = "AWS CLI command to start SSM session"
  value       = "aws ssm start-session --target ${aws_instance.dev_server.id} --region ${var.aws_region}"
}

output "ssm_port_forward_vscode" {
  description = "AWS CLI command to forward VS Code Server port"
  value       = "aws ssm start-session --target ${aws_instance.dev_server.id} --document-name AWS-StartPortForwardingSession --parameters 'portNumber=${var.vscode_port},localPortNumber=8080' --region ${var.aws_region}"
}

output "ssm_port_forward_claude" {
  description = "AWS CLI command to forward Claude Code UI port"
  value       = "aws ssm start-session --target ${aws_instance.dev_server.id} --document-name AWS-StartPortForwardingSession --parameters 'portNumber=${var.claude_ui_port},localPortNumber=3001' --region ${var.aws_region}"
}

# ============================================
# Cognito Information
# ============================================

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.main.id
  sensitive   = true
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

# ============================================
# VPC Information
# ============================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

# ============================================
# Certificate Information
# ============================================

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

# ============================================
# Backup Information
# ============================================

output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = var.enable_backup ? aws_backup_vault.main[0].arn : null
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = var.enable_backup ? aws_backup_plan.main[0].id : null
}

# ============================================
# S3 Bucket Information
# ============================================

output "alb_logs_bucket_name" {
  description = "Name of the S3 bucket for ALB access logs"
  value       = var.alb_access_logs_enabled ? aws_s3_bucket.alb_logs[0].id : null
}

output "alb_logs_bucket_arn" {
  description = "ARN of the S3 bucket for ALB access logs"
  value       = var.alb_access_logs_enabled ? aws_s3_bucket.alb_logs[0].arn : null
}

# ============================================
# Encryption Information
# ============================================

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.main.arn
}

# ============================================
# Instructions
# ============================================

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT

  ✅ Deployment Complete!

  1. Access your dev server:
     URL: https://${local.domain_name}

  2. Log in with Cognito:
     - Create users in Cognito User Pool Console
     - Or use AWS CLI: aws cognito-idp admin-create-user --user-pool-id ${aws_cognito_user_pool.main.id} --username <email> --region ${var.aws_region}

  3. SSH via SSM (no SSH keys needed):
     ${aws_instance.dev_server.id != "" ? "aws ssm start-session --target ${aws_instance.dev_server.id} --region ${var.aws_region}" : "Instance not ready yet"}

  4. Configure VS Code Remote SSH:
     - Install Session Manager plugin: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
     - Add to ~/.ssh/config:
       Host remote-dev
           HostName ${aws_instance.dev_server.id}
           User ubuntu
           ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --region ${var.aws_region}"

  5. Monitor logs:
     - EC2 user-data logs: sudo tail -f /var/log/cloud-init-output.log
     - Docker logs: docker logs code-server / docker logs claude-code-ui

  EOT
}
