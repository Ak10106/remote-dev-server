# Terraform Plan: Remote Development Server on EC2

## Overview
This Terraform repository will provision a secure, production-ready EC2 server for remote development with:
- **VS Code Server** (port 8080)
- **Claude Code UI** (port 3001)
- Mobile and laptop access via HTTPS
- AWS Cognito authentication
- SSM Session Manager for SSH (no SSH keys required)

## Architecture Decision: user_data vs EC2 Image Builder

### Comparison

| Aspect | user_data (Recommended) ✅ | EC2 Image Builder |
|--------|--------------------------|-------------------|
| **Setup Complexity** | Simple, inline script | Complex, separate pipeline |
| **Launch Time** | 5-10 min (setup on first boot) | <1 min (pre-baked) |
| **Iteration Speed** | Fast (just redeploy) | Slow (rebuild AMI each time) |
| **Cost** | Instance time only | Additional Image Builder costs |
| **Debugging** | CloudWatch logs, SSM | Must rebuild to test |
| **Maintenance** | Update script, redeploy | Rebuild & version AMIs |
| **Use Case Fit** | Single instance, dev environment | Auto-scaling, production fleets |

### Decision: **user_data with Docker** ✅

**Rationale:**
1. Single instance setup (not auto-scaling)
2. Development environment (faster iteration needed)
3. Docker provides consistency and easy updates
4. Simpler maintenance and debugging
5. Lower cost and complexity

## Architecture Components

### 1. Simplified Architecture (ALB Only)
```
Internet (0.0.0.0/0:443)
    ↓
Route53: dev.your-domain.com (configurable subdomain)
    ↓
Application Load Balancer (HTTPS:443)
    ↓ ACM Certificate (free, auto-renewal)
    ↓ [Cognito Authentication]
    ↓
Target Groups (HTTP)
    ├── VS Code Server (8080)
    └── Claude Code UI (3001)
    ↓
EC2 Instance (Private Subnet + NAT Gateway)
    ├── Docker Container: code-server
    └── Docker Container: claude-code-ui
```

**Key Points:**
- No CloudFront (simpler, lower latency)
- Uses existing Route53 domain (configurable subdomain)
- Free ACM certificate with DNS validation
- End-to-end HTTPS encryption

### 2. Access Methods
- **Web Access**: HTTPS via ALB → Cognito Auth → Services
- **SSH Access**: AWS SSM Session Manager (no direct SSH, no keys)
- **Mobile Access**: HTTPS from any device via domain name

### 3. Security Architecture
```
Security Groups:
├── ALB Security Group
│   ├── Ingress: 0.0.0.0/0:443 (HTTPS)
│   └── Egress: EC2 SG:8080,3001
│
└── EC2 Security Group
    ├── Ingress: ALB SG:8080,3001
    ├── Egress: 0.0.0.0/0:443 (for updates)
    └── SSM: Managed by AWS (no open ports)
```

### 4. Authentication Flow
```
User Request → ALB (HTTPS:443)
    ↓
Cognito User Pool Authentication
    ↓ [Success]
ALB forwards to Target Group
    ↓
EC2 Instance (HTTP:8080 or :3001)
```

## Terraform Repository Structure

```
.
├── README.md                    # Comprehensive documentation
├── PLAN.md                     # This file
├── .gitignore                  # Terraform gitignore
│
├── terraform.tfvars.example    # Example configuration
├── terraform.tfvars            # Actual values (git-ignored)
│
├── versions.tf                 # Terraform & provider versions
├── providers.tf                # AWS provider configuration
├── variables.tf                # Input variable definitions
├── locals.tf                   # Computed local values
├── outputs.tf                  # Output values
│
├── data.tf                     # Data sources (AMI, AZs, etc.)
├── vpc.tf                      # VPC resources (optional)
├── security_groups.tf          # Security groups
├── iam.tf                      # IAM roles and policies
├── acm.tf                      # ACM certificate
├── cognito.tf                  # Cognito user pool
├── alb.tf                      # Application Load Balancer
├── ec2.tf                      # EC2 instance
├── route53.tf                  # DNS records (optional)
├── backup.tf                   # AWS Backup (optional)
│
├── scripts/
│   ├── user_data.sh           # EC2 bootstrap script
│   └── docker-compose.yml     # Docker services definition
│
└── modules/                    # (Future: modularize if needed)
    ├── networking/
    ├── compute/
    └── security/
```

## Configuration Variables (terraform.tfvars)

### Required Variables
```hcl
# Region
aws_region = "ap-northeast-1"

# Instance Configuration
instance_type = "t3.medium"
root_volume_size = 100
ami_name_filter = "ubuntu/images/hbn-ssd/ubuntu-noble-24.04-amd64-server-*"

# Domain & Certificate
domain_name = "dev.example.com"          # Your domain
hosted_zone_id = "Z1234567890ABC"        # Route53 zone ID

# Cognito
cognito_user_pool_name = "dev-server-users"
cognito_admin_email = "admin@example.com"
```

### Optional/Configurable Variables
```hcl
# Networking
create_vpc = true                         # true = new VPC, false = use existing
vpc_id = ""                              # If create_vpc = false
vpc_cidr = "10.0.0.0/16"

# Backup
enable_backup = true
backup_retention_days = 7
backup_schedule = "cron(0 2 * * ? *)"    # Daily at 2 AM JST

# Tags
environment = "development"
project = "remote-dev-server"

# VS Code Server
vscode_password = ""                      # Optional: additional password

# Claude Code
claude_api_key = ""                       # Set via environment or SSM Parameter
```

## Implementation Steps

### Phase 1: Core Infrastructure (Steps 1-3)
1. **Terraform Setup**
   - versions.tf, providers.tf
   - variables.tf with all configurable options
   - locals.tf for computed values
   - terraform.tfvars.example

2. **Networking**
   - VPC with public/private subnets (if create_vpc = true)
   - Internet Gateway, NAT Gateway
   - Route tables
   - Or use existing VPC (configurable)

3. **Security Groups**
   - ALB SG: Allow 443 from 0.0.0.0/0
   - EC2 SG: Allow 8080,3001 from ALB SG only
   - VPC Endpoints for SSM (private subnet)

### Phase 2: SSL & Authentication (Steps 4-5)
4. **ACM Certificate**
   - Request certificate for domain
   - DNS validation records
   - Wait for validation

5. **Cognito User Pool**
   - User pool with email verification
   - App client for ALB integration
   - Domain name for hosted UI
   - Admin user creation

### Phase 3: Load Balancer (Step 6)
6. **Application Load Balancer**
   - Public subnets
   - HTTPS listener (443) with ACM certificate
   - Cognito authentication action
   - Target groups for VS Code (8080) and Claude UI (3001)
   - Path-based routing:
     - `/` → Claude Code UI
     - `/vscode/*` → VS Code Server (with rewrite)
   - Health checks

### Phase 4: Compute (Steps 7-8)
7. **IAM Role for EC2**
   - SSM Session Manager permissions
   - CloudWatch Logs permissions
   - Secrets Manager access (for API keys)
   - S3 access for backups (optional)

8. **EC2 Instance**
   - Ubuntu 24.04 LTS AMI
   - t3.medium
   - 100GB gp3 root volume
   - Private subnet
   - IAM instance profile
   - user_data script

### Phase 5: Application Setup (Step 9)
9. **Docker Compose (user_data)**
   ```yaml
   services:
     code-server:
       image: codercom/code-server:latest
       ports: ["8080:8080"]
       volumes: ["/home/ubuntu/workspace:/home/coder/project"]
       environment:
         - PASSWORD=${VSCODE_PASSWORD}

     claude-code-ui:
       image: node:22
       working_dir: /app
       ports: ["3001:3001"]
       volumes: ["./claudecodeui:/app"]
       command: npx @siteboon/claude-code-ui
   ```

### Phase 6: Optional Features (Steps 10-11)
10. **Route53 DNS** (if domain configured)
    - A record: dev.example.com → ALB
    - ACM validation records

11. **AWS Backup** (if enabled)
    - Backup plan with daily snapshots
    - Retention policy
    - Backup vault

## Access Guide

### Web Access
1. Navigate to `https://dev.example.com`
2. Cognito login page appears
3. Enter credentials
4. Access Claude Code UI (default) or VS Code Server

### SSH Access via SSM
```bash
# Install Session Manager plugin
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Start session
aws ssm start-session --target <instance-id> --region ap-northeast-1

# VS Code Remote SSH via SSM
# Add to ~/.ssh/config:
Host remote-dev
    HostName <instance-id>
    User ubuntu
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

### Mobile Access
- Use Safari/Chrome on iOS/Android
- Navigate to `https://dev.example.com`
- Login with Cognito
- Full responsive UI for both services

## Cost Estimation (ap-northeast-1)

| Resource | Estimated Monthly Cost |
|----------|------------------------|
| EC2 t3.medium (730 hrs) | ~$30 |
| EBS gp3 100GB | ~$8 |
| ALB | ~$23 |
| NAT Gateway | ~$33 |
| Data Transfer (10GB out) | ~$1.5 |
| Route53 Hosted Zone | $0.50 |
| **Total** | **~$96/month** |

*Note: NAT Gateway is most expensive - consider removing if EC2 in public subnet is acceptable*

## Security Considerations

✅ **Implemented:**
- HTTPS only (no HTTP)
- Cognito authentication
- Private EC2 instance (no direct internet access)
- SSM Session Manager (no SSH keys)
- Security groups with least privilege
- Encrypted EBS volumes
- Regular backups

⚠️ **Additional Recommendations:**
- Enable CloudTrail for audit logging
- Set up CloudWatch alarms for unusual activity
- Use AWS Secrets Manager for API keys
- Enable VPC Flow Logs
- Regular security patching via user_data updates
- Consider AWS WAF on ALB for additional protection

## Post-Deployment Steps

1. **Verify SSL Certificate**: Ensure ACM certificate is validated
2. **Create Cognito Users**: Add team members to user pool
3. **Configure Claude API Keys**: Store in Secrets Manager or environment
4. **Test SSM Access**: Verify SSM Session Manager works
5. **Setup Monitoring**: CloudWatch alarms for health checks
6. **Backup Verification**: Test restore from backup

## Future Enhancements

- [ ] Auto Scaling (if needed for multiple users)
- [ ] Multi-region deployment
- [ ] Custom domain for Cognito
- [ ] MFA for Cognito
- [ ] AWS WAF rules
- [ ] Terraform modules for reusability
- [ ] CI/CD pipeline for infrastructure updates
- [ ] Monitoring dashboard (Grafana)

## Questions / Decisions Needed

1. **Domain Name**: Do you have a domain registered in Route53?
2. **Cognito Users**: Should I create an initial admin user automatically?
3. **VPC**: Create new VPC or use existing default VPC?
4. **NAT Gateway**: Accept cost (~$33/mo) or use public subnet for EC2?
5. **Claude API Keys**: How should we inject them? (Secrets Manager, SSM Parameter, or manual setup?)

---

**Ready to proceed?** Let me know if you have questions or want changes to the plan!
