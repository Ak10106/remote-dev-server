# ============================================
# Data Sources
# ============================================

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get existing Route53 hosted zone
data "aws_route53_zone" "main" {
  zone_id = var.route53_zone_id
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Random password for origin verification header
resource "random_password" "origin_verification" {
  length  = 32
  special = true
}
