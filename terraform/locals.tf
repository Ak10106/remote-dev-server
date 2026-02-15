locals {
  # ============================================
  # Naming
  # ============================================
  name_prefix = var.project_name

  # Full domain name
  domain_name = "${var.subdomain_name}.${var.root_domain_name}"

  # ============================================
  # Networking
  # ============================================
  # Use provided AZs or default to first 2 in region
  azs = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${var.aws_region}a",
    "${var.aws_region}c"
  ]

  # Number of subnets
  num_azs = length(local.azs)

  # ============================================
  # Tags
  # ============================================
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }

  # ============================================
  # Application Ports
  # ============================================
  target_groups = {
    vscode = {
      port                 = var.vscode_port
      protocol             = "HTTP"
      health_check_path    = "/"
      health_check_matcher = "200,302"
    }
    claude_ui = {
      port                 = var.claude_ui_port
      protocol             = "HTTP"
      health_check_path    = "/"
      health_check_matcher = "200"
    }
  }

  # ============================================
  # Security
  # ============================================
  # Custom header for ALB origin verification
  origin_verify_header_name  = "X-Origin-Verify"
  origin_verify_header_value = random_password.origin_verification.result
}
