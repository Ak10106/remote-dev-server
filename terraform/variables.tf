# ============================================
# General Configuration
# ============================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging (max 15 characters recommended)"
  type        = string
  default     = "remote-dev-server"

  validation {
    condition     = length(var.project_name) <= 20
    error_message = "Project name must be 20 characters or less to avoid AWS resource naming limits."
  }
}


# ============================================
# Domain & DNS Configuration
# ============================================

variable "root_domain_name" {
  description = "Existing root domain name managed in Route53 (e.g., example.com)"
  type        = string
}

variable "subdomain_name" {
  description = "Subdomain name for the dev server (e.g., 'dev' creates dev.example.com)"
  type        = string
  default     = "dev"
}

variable "route53_zone_id" {
  description = "Existing Route53 hosted zone ID for root domain (REQUIRED)"
  type        = string
}

# ============================================
# VPC & Networking Configuration
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use. If empty, will use first 2 AZs in region"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (required for EC2 to access internet)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all AZs (cost saving). Set false for high availability"
  type        = bool
  default     = true
}

# ============================================
# EC2 Instance Configuration
# ============================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 100
}

variable "root_volume_type" {
  description = "Type of root EBS volume (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

variable "ami_name_filter" {
  description = "AMI name filter for Ubuntu 24.04 LTS"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "ami_owner" {
  description = "AMI owner ID (099720109477 = Canonical for Ubuntu)"
  type        = string
  default     = "099720109477"
}

# ============================================
# Application Configuration
# ============================================

variable "vscode_port" {
  description = "Port for VS Code Server"
  type        = number
  default     = 8080
}

variable "claude_ui_port" {
  description = "Port for Claude Code UI"
  type        = number
  default     = 3001
}

variable "vscode_password" {
  description = "Optional password for VS Code Server. If empty, password auth is disabled"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================
# Cognito Configuration
# ============================================

variable "cognito_user_pool_name" {
  description = "Name for Cognito User Pool"
  type        = string
  default     = "remote-dev-server-users"
}

variable "cognito_domain_prefix" {
  description = "Domain prefix for Cognito hosted UI (must be globally unique)"
  type        = string
}

variable "create_cognito_admin_user" {
  description = "Whether to create an admin user in Cognito (not recommended for production)"
  type        = bool
  default     = false
}

variable "cognito_admin_email" {
  description = "Email for Cognito admin user (if create_cognito_admin_user = true)"
  type        = string
  default     = ""
}

# ============================================
# Backup Configuration
# ============================================

variable "enable_backup" {
  description = "Enable AWS Backup for EC2 instance"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Backup schedule in cron format (UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC (11 AM JST)
}

# ============================================
# Security Configuration
# ============================================

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB (default: 0.0.0.0/0 for public access)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ssm_session_manager" {
  description = "Enable SSM Session Manager for EC2 access (recommended)"
  type        = bool
  default     = true
}

# ============================================
# Monitoring & Logging
# ============================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2"
  type        = bool
  default     = false
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs (S3 bucket will be created automatically)"
  type        = bool
  default     = false
}
