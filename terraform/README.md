# Remote Development Server on AWS

This Terraform configuration deploys a secure, production-ready remote development server on AWS with VS Code Server and Claude Code UI.

## Architecture

```
Internet (Mobile/Laptop)
    ↓ HTTPS
Route53: dev.your-domain.com
    ↓
ALB (HTTPS:443 with ACM certificate)
    ↓ AWS Cognito Authentication
    ↓
EC2 Instance (Private Subnet + NAT Gateway)
    ├── Docker: VS Code Server :8080
    └── Docker: Claude Code UI :3001
```

## Features

✅ **Secure Access**
- HTTPS-only with free ACM certificate
- AWS Cognito authentication
- Private EC2 instance (no public IP)
- SSM Session Manager for SSH (no SSH keys needed)

✅ **Remote Development**
- VS Code Server for full IDE experience
- Claude Code UI for AI-assisted coding
- Docker containers for easy management

✅ **High Availability & Backup**
- Multi-AZ deployment
- Automated daily backups with AWS Backup
- NAT Gateway for secure internet access

✅ **Cost Optimized**
- Single NAT Gateway option (~$86/month)
- Configurable instance types
- Auto-renewal ACM certificates (free)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Existing Domain** managed in Route53 (or ability to create one)
3. **AWS CLI** configured with credentials
4. **Terraform** >= 1.5.0 installed

## Quick Start

### 1. Clone and Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit `terraform.tfvars`

**Required variables:**
```hcl
owner_email          = "your.email@example.com"
root_domain_name     = "example.com"           # Your existing domain
subdomain_name       = "dev"                   # Creates dev.example.com
route53_zone_id      = "Z1234567890ABC"       # Your Route53 zone ID
cognito_domain_prefix = "your-unique-prefix"   # Must be globally unique
```

**Find your Route53 Zone ID:**
```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
# Review the plan
terraform plan

# Apply (takes ~10-15 minutes)
terraform apply
```

### 5. Access Your Server

After deployment, Terraform will output:
- **Server URL**: `https://dev.your-domain.com`
- **VS Code URL**: `https://dev.your-domain.com/vscode`
- **SSM Command**: For SSH access

## Configuration Options

### Instance Sizing

| Instance Type | vCPU | Memory | Cost/month (ap-northeast-1) |
|---------------|------|--------|------------------------------|
| t3.small      | 2    | 2 GB   | ~$15                         |
| t3.medium     | 2    | 4 GB   | ~$30 (default)              |
| t3.large      | 2    | 8 GB   | ~$60                         |
| t3.xlarge     | 4    | 16 GB  | ~$120                        |

### Cost Optimization

**Single NAT Gateway** (default):
```hcl
single_nat_gateway = true  # ~$33/month, lower HA
```

**Multi-AZ NAT Gateway** (high availability):
```hcl
single_nat_gateway = false  # ~$66/month, full HA
```

### Cognito Users

Create users after deployment:

```bash
# Get User Pool ID from outputs
terraform output cognito_user_pool_id

# Create user
aws cognito-idp admin-create-user \
  --user-pool-id <pool-id> \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
  --region ap-northeast-1

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <pool-id> \
  --username user@example.com \
  --password "YourSecurePassword123!" \
  --permanent \
  --region ap-northeast-1
```

## SSH Access via SSM

### Install Session Manager Plugin

**macOS:**
```bash
brew install --cask session-manager-plugin
```

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

### Connect to Instance

```bash
# Get instance ID
terraform output ec2_instance_id

# Start session
aws ssm start-session --target <instance-id> --region ap-northeast-1
```

### VS Code Remote SSH

Add to `~/.ssh/config`:

```
Host remote-dev
    HostName <instance-id>
    User ubuntu
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --region ap-northeast-1"
```

Then connect:
```bash
code --remote ssh-remote+remote-dev /home/ubuntu/workspace
```

## Monitoring & Logs

### Application Logs

```bash
# SSH into instance via SSM
aws ssm start-session --target <instance-id> --region ap-northeast-1

# View logs
sudo tail -f /var/log/user-data.log          # Setup logs
docker logs -f code-server                    # VS Code Server
docker logs -f claude-code-ui                 # Claude UI
```

### CloudWatch Logs

```bash
# View log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/remote-dev" --region ap-northeast-1

# Tail logs
aws logs tail /aws/ec2/remote-dev-server-development --follow --region ap-northeast-1
```

## Backup & Recovery

### Manual Backup

```bash
# Create backup
aws backup start-backup-job \
  --backup-vault-name <vault-name> \
  --resource-arn <instance-arn> \
  --iam-role-arn <backup-role-arn> \
  --region ap-northeast-1
```

### Restore from Backup

1. Find recovery point:
```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name> \
  --region ap-northeast-1
```

2. Restore via AWS Console or CLI following [AWS Backup documentation](https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-ec2.html)

## Troubleshooting

### ACM Certificate Stuck in "Pending Validation"

```bash
# Check validation records
terraform state show aws_route53_record.cert_validation

# Verify Route53 zone
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>
```

**Solution:** Ensure DNS records are correctly created in Route53.

### Cannot Access Server (502/503 Error)

1. Check EC2 health:
```bash
aws ssm start-session --target <instance-id> --region ap-northeast-1
systemctl status docker
docker ps
```

2. Check ALB target health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region ap-northeast-1
```

3. Review logs:
```bash
sudo tail -f /var/log/user-data.log
docker logs code-server
```

### Cognito Authentication Issues

1. Verify callback URLs match:
```bash
terraform output dev_server_url
# Should match Cognito client callback URL
```

2. Check user status:
```bash
aws cognito-idp admin-get-user \
  --user-pool-id <pool-id> \
  --username user@example.com \
  --region ap-northeast-1
```

### SSM Session Manager Not Working

1. Verify VPC endpoints:
```bash
aws ec2 describe-vpc-endpoints --region ap-northeast-1
```

2. Check IAM role:
```bash
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --region ap-northeast-1
```

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Confirm with 'yes'
```

**Note:** Backups in AWS Backup vault are NOT automatically deleted. Remove them manually if needed.

## Security Best Practices

1. **Restrict Access**:
   ```hcl
   allowed_cidr_blocks = ["YOUR_IP/32"]  # Your office/home IP only
   ```

2. **Enable MFA** for Cognito users via AWS Console

3. **Regular Updates**:
   ```bash
   # SSH into instance
   sudo apt update && sudo apt upgrade -y
   docker compose pull  # Update Docker images
   docker compose up -d
   ```

4. **Monitor Costs**:
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2024-01-01,End=2024-01-31 \
     --granularity MONTHLY \
     --metrics BlendedCost \
     --group-by Type=TAG,Key=Project
   ```

## Cost Breakdown (ap-northeast-1)

| Resource                  | Cost/Month |
|---------------------------|------------|
| EC2 t3.medium (730 hrs)   | ~$30       |
| EBS gp3 100GB             | ~$8        |
| ALB                       | ~$23       |
| NAT Gateway (single)      | ~$33       |
| Data Transfer (10GB out)  | ~$1.5      |
| Route53 Hosted Zone       | $0.50      |
| **Total**                 | **~$96**   |

**Cost Saving Options:**
- Use t3.small: Save $15/month
- Disable NAT Gateway (use public subnet): Save $33/month (⚠️ less secure)
- Stop EC2 when not in use: Save ~$30/month (EBS charges continue)

## Support & Resources

- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VS Code Server](https://github.com/coder/code-server)
- [Claude Code UI](https://github.com/siteboon/claudecodeui)

## License

This Terraform configuration is provided as-is under the MIT License.
