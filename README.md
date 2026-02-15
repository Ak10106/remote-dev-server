# Remote Development Server on AWS

Infrastructure as Code (Terraform) for deploying a secure remote development server on AWS EC2 with VS Code Server and Claude Code UI.

## 🚀 Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
terraform init
terraform plan
terraform apply
```

## 📋 What's Included

- **VS Code Server** - Full IDE experience in the browser
- **Claude Code UI** - AI-assisted coding interface
- **AWS Cognito** - Secure authentication
- **HTTPS** - Free ACM certificate with auto-renewal
- **SSM Session Manager** - Secure SSH access without keys
- **Automated Backups** - Daily snapshots with AWS Backup
- **Docker-based** - Easy updates and management

## 🏗️ Architecture

```
User (HTTPS) → Route53 → ALB (Cognito Auth) → EC2 (Private Subnet)
                                                  ├── VS Code Server
                                                  └── Claude Code UI
```

**Security Features:**
- EC2 in private subnet (no public IP)
- NAT Gateway for outbound internet
- Security groups with least privilege
- IMDSv2 enforced
- Encrypted EBS volumes

## 📁 Repository Structure

```
.
├── README.md                    # This file
├── PLAN.md                      # Detailed implementation plan
└── terraform/                   # Terraform configuration
    ├── README.md                # Detailed deployment guide
    ├── versions.tf              # Terraform version constraints
    ├── providers.tf             # AWS provider configuration
    ├── variables.tf             # Input variables
    ├── locals.tf                # Local computed values
    ├── outputs.tf               # Output values
    ├── data.tf                  # Data sources
    ├── vpc.tf                   # VPC and networking
    ├── security_groups.tf       # Security groups
    ├── route53.tf               # DNS records
    ├── acm.tf                   # SSL certificates
    ├── cognito.tf               # Authentication
    ├── alb.tf                   # Load balancer
    ├── iam.tf                   # IAM roles and policies
    ├── ec2.tf                   # EC2 instance
    ├── backup.tf                # AWS Backup configuration
    ├── terraform.tfvars.example # Example configuration
    └── scripts/
        ├── user_data.sh         # EC2 bootstrap script
        └── docker-compose.yml   # Docker services
```

## 📖 Documentation

- **[Terraform README](terraform/README.md)** - Complete deployment guide, troubleshooting, and usage
- **[Implementation Plan](PLAN.md)** - Architecture decisions and design rationale

## 💰 Estimated Cost

| Component | Monthly Cost (ap-northeast-1) |
|-----------|-------------------------------|
| EC2 t3.medium | ~$30 |
| EBS 100GB | ~$8 |
| ALB | ~$23 |
| NAT Gateway | ~$33 |
| Data Transfer | ~$1.5 |
| **Total** | **~$96/month** |

## 🔧 Prerequisites

1. AWS Account with appropriate permissions
2. Existing domain in Route53 (or create one)
3. AWS CLI configured
4. Terraform >= 1.5.0

## 🛠️ Configuration

### Required Variables

```hcl
owner_email          = "your.email@example.com"
root_domain_name     = "example.com"
subdomain_name       = "dev"
route53_zone_id      = "Z1234567890ABC"
cognito_domain_prefix = "your-unique-prefix"
```

### Find Your Route53 Zone ID

```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text
```

## 🔐 Access

After deployment:

1. **Web Access**: `https://dev.your-domain.com`
2. **SSH Access**:
   ```bash
   aws ssm start-session --target <instance-id> --region ap-northeast-1
   ```

## 📚 Key Features

### Security
- ✅ HTTPS-only (HTTP redirects to HTTPS)
- ✅ AWS Cognito authentication
- ✅ Private subnet deployment
- ✅ SSM Session Manager (no SSH keys)
- ✅ Security groups with least privilege
- ✅ Encrypted EBS volumes
- ✅ IMDSv2 enforced

### High Availability
- ✅ Multi-AZ VPC
- ✅ ALB health checks
- ✅ Auto-recovery
- ✅ Daily backups

### Developer Experience
- ✅ VS Code Server (full IDE)
- ✅ Claude Code UI (AI assistance)
- ✅ Docker-based (easy updates)
- ✅ Git pre-installed
- ✅ AWS CLI v2
- ✅ Node.js 22

## 🔄 Updates

```bash
# Update infrastructure
terraform plan
terraform apply

# Update Docker containers
aws ssm start-session --target <instance-id>
cd /home/ubuntu
docker compose pull
docker compose up -d
```

## 🧹 Cleanup

```bash
terraform destroy
```

**Note:** AWS Backup vaults are not automatically deleted. Remove manually if needed.

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

This is a template repository. Feel free to fork and customize for your needs!

## 📞 Support

- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [VS Code Server](https://github.com/coder/code-server)
- [Claude Code UI](https://github.com/siteboon/claudecodeui)

---

**Built with ❤️ using Terraform and AWS**
