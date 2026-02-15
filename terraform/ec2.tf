# ============================================
# EC2 Instance
# ============================================

resource "aws_instance" "dev_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Network
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = false

  # IAM
  iam_instance_profile = aws_iam_instance_profile.ec2.name

  # EBS optimization (required for security compliance)
  ebs_optimized = true

  # Storage
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = false # Keep EBS volume when instance is replaced
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${local.name_prefix}-root-volume"
      }
    )
  }

  # Monitoring
  monitoring = var.enable_detailed_monitoring

  # User Data
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    # Application Configuration
    vscode_password  = var.vscode_password != "" ? var.vscode_password : "disabled"
    vscode_auth_type = var.vscode_password != "" ? "password" : "none"
    aws_region       = var.aws_region
    domain_name      = local.domain_name

    # Docker Compose Content
    docker_compose_content = file("${path.module}/scripts/docker-compose.yml")

    # Monitoring
    enable_cloudwatch_logs = true
    project_name           = var.project_name
  })

  # User data replacement
  user_data_replace_on_change = true

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2"
    }
  )

  # Dependency
  depends_on = [
    aws_nat_gateway.main,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages
  ]

  lifecycle {
    ignore_changes = [
      ami, # Prevent replacement on AMI updates
    ]
  }
}

# ============================================
# CloudWatch Log Group
# ============================================

resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/aws/ec2/${local.name_prefix}"
  retention_in_days = 365 # Retain logs for 1 year (compliance requirement)
  kms_key_id        = aws_kms_key.main.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-logs"
    }
  )
}
