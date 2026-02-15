# Claude Code Best Practices for This Repository

## Common Mistakes to Avoid

### 1. File Edit Commands
**CRITICAL**: Always read a file before editing it!

```bash
# ❌ WRONG - Will fail
Edit tool on file without reading first

# ✅ CORRECT - Read first
Read tool → then Edit tool
```

**Rule**: The Edit tool requires the file to be read in the current conversation before editing.

### 2. Current Working Directory
**CRITICAL**: Always be aware of the current working directory!

```bash
# Check directory before running commands
pwd

# This repository structure:
/Users/suemasay/workspaces/cloud_ui/          # Root
  ├── terraform/                              # All .tf files here
  │   ├── *.tf                                # Terraform configuration
  │   └── scripts/                            # User data and Docker Compose
  ├── PLAN.md
  ├── README.md
  └── CLAUDE.md                               # This file
```

**Common directory confusion**:
- Working directory starts at: `/Users/suemasay/workspaces/cloud_ui/`
- Terraform commands must run from: `terraform/` subdirectory
- Use `cd terraform &&` or provide full paths

### 3. Terraform Commands
**Always run terraform commands from the terraform directory**:

```bash
# ❌ WRONG
terraform plan  # If not in terraform/

# ✅ CORRECT
cd terraform && terraform plan
# OR
terraform -chdir=terraform plan
```

### 4. AWS Credentials
**Profile**: `suemasay+personalisengard-Admin`

```bash
# Set profile for AWS commands
AWS_PROFILE=suemasay+personalisengard-Admin aws <command>

# OR export it
export AWS_PROFILE=suemasay+personalisengard-Admin
```

### 5. Code Defender
**Repository**: `git@github.com:Ak10106/remote-dev-server.git`

Every push requires re-approval:
```bash
git-defender --request-repo --url git@github.com:Ak10106/remote-dev-server.git --reason 3
```

Wait for user confirmation before pushing.

## Repository-Specific Rules

### AMI Configuration
- **Filter**: `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*`
- **Note**: Must use `hvm-ssd-gp3` (not `hvm-ssd`)
- **Owner**: 099720109477 (Canonical)

### Resource Naming Limits
- **project_name**: Max 20 characters
- **Target Groups**: Max 32 chars → uses `{project_name}-vscode-tg`
- **S3 Bucket**: Max 37 chars → uses `{project_name}-alb-logs-`
- **IAM Roles**: Max 38 chars → uses `{project_name}-vpc-flow-`

### Variables Removed
- ❌ `environment` - No longer used
- ❌ `owner_email` - No longer used
- ✅ `project_name` - Used as sole name_prefix

### Security Standards
- KMS encryption for all data at rest
- VPC Flow Logs enabled
- CloudWatch logs with 1-year retention
- EBS optimization enabled
- checkov security scan: 162 passed / 22 acceptable failures

### ACM Certificate Validation
**ALREADY CONFIGURED** - Certificate validation is fully automated:

```hcl
# terraform/acm.tf handles this automatically:
1. aws_acm_certificate - Requests cert with DNS validation
2. aws_route53_record - Creates validation DNS records
3. aws_acm_certificate_validation - Waits for validation (10m timeout)
```

**How it works**:
- ACM generates random DNS validation records
- Terraform creates those records in Route53 automatically
- ACM polls Route53 to verify records (usually takes 1-5 minutes)
- Validation resource blocks until complete
- ALB listener uses `aws_acm_certificate_validation.main.certificate_arn`

**No manual intervention needed!** Just ensure Route53 zone exists and is accessible.

## Workflow Checklist

When making changes:

1. ✅ Check current directory: `pwd`
2. ✅ Read file before editing: Use Read tool first
3. ✅ Validate: `cd terraform && terraform validate`
4. ✅ Format: `terraform fmt -recursive`
5. ✅ Security scan: `checkov -d terraform --framework terraform --compact`
6. ✅ Commit with short message
7. ✅ Wait for Code Defender approval before pushing

## Key Files

| File | Purpose | Must Read Before Editing |
|------|---------|--------------------------|
| terraform/variables.tf | Variable definitions | ✅ Yes |
| terraform/locals.tf | Computed values | ✅ Yes |
| terraform/data.tf | Data sources & AMI | ✅ Yes |
| terraform/*.tf | All Terraform config | ✅ Yes |

## Quick Reference

```bash
# Current directory
/Users/suemasay/workspaces/cloud_ui/

# Terraform directory
cd terraform

# AWS Profile
export AWS_PROFILE=suemasay+personalisengard-Admin

# Terraform workflow
terraform init
terraform validate
terraform plan
terraform apply

# Git workflow
git status
git add <files>
git commit -m "message"
# Wait for Code Defender approval
git push
```

## Remember

- **Read before Edit** - Every single time!
- **Know your directory** - Check with `pwd`
- **AWS Profile** - Always set before AWS/Terraform commands
- **Code Defender** - Wait for approval before pushing
