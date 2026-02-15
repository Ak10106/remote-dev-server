# ============================================
# ALB Security Group
# ============================================

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTPS inbound from internet
resource "aws_security_group_rule" "alb_https_in" {
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
}

# Allow HTTP redirect (optional, for HTTPS redirect)
resource "aws_security_group_rule" "alb_http_in" {
  type              = "ingress"
  description       = "HTTP from internet (redirect to HTTPS)"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
}

# Allow outbound to EC2 on application ports
resource "aws_security_group_rule" "alb_to_ec2_vscode" {
  type                     = "egress"
  description              = "To EC2 VS Code Server"
  from_port                = var.vscode_port
  to_port                  = var.vscode_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_to_ec2_claude" {
  type                     = "egress"
  description              = "To EC2 Claude Code UI"
  from_port                = var.claude_ui_port
  to_port                  = var.claude_ui_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.alb.id
}

# ============================================
# EC2 Security Group
# ============================================

resource "aws_security_group" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"
  description = "Security group for EC2 dev server"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow VS Code Server from ALB
resource "aws_security_group_rule" "ec2_vscode_from_alb" {
  type                     = "ingress"
  description              = "VS Code Server from ALB"
  from_port                = var.vscode_port
  to_port                  = var.vscode_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ec2.id
}

# Allow Claude Code UI from ALB
resource "aws_security_group_rule" "ec2_claude_from_alb" {
  type                     = "ingress"
  description              = "Claude Code UI from ALB"
  from_port                = var.claude_ui_port
  to_port                  = var.claude_ui_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ec2.id
}

# Allow all outbound (for updates, Docker pulls, etc.)
resource "aws_security_group_rule" "ec2_all_out" {
  type              = "egress"
  description       = "Allow all outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}
