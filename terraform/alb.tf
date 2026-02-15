# ============================================
# Application Load Balancer
# ============================================

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # Access logs (optional)
  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []

    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      enabled = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )

  # Ensure S3 bucket policy is applied before ALB tries to write logs
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# ============================================
# Target Groups
# ============================================

# VS Code Server Target Group
resource "aws_lb_target_group" "vscode" {
  name     = "${local.name_prefix}-vscode-tg"
  port     = var.vscode_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200,302"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vscode-tg"
    }
  )
}

# Claude Code UI Target Group
resource "aws_lb_target_group" "claude_ui" {
  name     = "${local.name_prefix}-claude-tg"
  port     = var.claude_ui_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-claude-tg"
    }
  )
}

# ============================================
# Target Group Attachments
# ============================================

resource "aws_lb_target_group_attachment" "vscode" {
  target_group_arn = aws_lb_target_group.vscode.arn
  target_id        = aws_instance.dev_server.id
  port             = var.vscode_port
}

resource "aws_lb_target_group_attachment" "claude_ui" {
  target_group_arn = aws_lb_target_group.claude_ui.arn
  target_id        = aws_instance.dev_server.id
  port             = var.claude_ui_port
}

# ============================================
# HTTP Listener (Redirect to HTTPS)
# ============================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-http-listener"
    }
  )
}

# ============================================
# HTTPS Listener with Cognito Auth
# ============================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  # Default action: Authenticate with Cognito, then forward to Claude UI
  default_action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.main.arn
      user_pool_client_id = aws_cognito_user_pool_client.main.id
      user_pool_domain    = aws_cognito_user_pool_domain.main.domain

      on_unauthenticated_request = "authenticate"
      scope                      = "openid email profile"
      session_cookie_name        = "AWSELBAuthSessionCookie"
      session_timeout            = 3600 # 1 hour
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.claude_ui.arn
    order            = 2
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-https-listener"
    }
  )
}

# ============================================
# Listener Rules
# ============================================

# Route /vscode* to VS Code Server
resource "aws_lb_listener_rule" "vscode" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.main.arn
      user_pool_client_id = aws_cognito_user_pool_client.main.id
      user_pool_domain    = aws_cognito_user_pool_domain.main.domain

      on_unauthenticated_request = "authenticate"
      scope                      = "openid email profile"
      session_cookie_name        = "AWSELBAuthSessionCookie"
      session_timeout            = 3600
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vscode.arn
    order            = 2
  }

  condition {
    path_pattern {
      values = ["/vscode*"]
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vscode-rule"
    }
  )
}
