# ============================================
# EC2 IAM Role
# ============================================

resource "aws_iam_role" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-role"
    }
  )
}

# ============================================
# IAM Policies
# ============================================

# SSM Session Manager Policy
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  count = var.enable_ssm_session_manager ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "ec2_cloudwatch_logs" {
  name_prefix = "${local.name_prefix}-ec2-logs-"
  role        = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${local.name_prefix}*"
        ]
      }
    ]
  })
}

# Bedrock Policy (for Claude Code CLI)
resource "aws_iam_role_policy" "ec2_bedrock" {
  name_prefix = "${local.name_prefix}-ec2-bedrock-"
  role        = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-*"
        ]
      }
    ]
  })
}

# Systems Manager Parameter Store (for secrets)
resource "aws_iam_role_policy" "ec2_ssm_parameters" {
  name_prefix = "${local.name_prefix}-ec2-ssm-params-"
  role        = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.name_prefix}/*"
        ]
      }
    ]
  })
}

# ECR Pull Policy (for Docker images)
resource "aws_iam_role_policy" "ec2_ecr" {
  name_prefix = "${local.name_prefix}-ec2-ecr-"
  role        = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================
# Instance Profile
# ============================================

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${local.name_prefix}-ec2-"
  role        = aws_iam_role.ec2.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-profile"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
