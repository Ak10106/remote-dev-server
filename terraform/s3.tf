# ============================================
# S3 Bucket for ALB Access Logs
# ============================================

resource "aws_s3_bucket" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket_prefix = "${local.name_prefix}-alb-logs-"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-alb-logs"
      Purpose = "ALB Access Logs"
    }
  )
}

# Enable versioning
resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with S3-managed keys (SSE-S3)
# Note: ALB access logs only support SSE-S3, not KMS encryption
# Reference: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # S3-managed encryption (SSE-S3)
    }
    bucket_key_enabled = false # Not applicable for SSE-S3
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule for log retention
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90 # Keep logs for 90 days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy for ALB access logs
# Reference: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.alb_access_logs_enabled ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })

  # Ensure all bucket configurations are complete before applying policy
  depends_on = [
    aws_s3_bucket_public_access_block.alb_logs,
    aws_s3_bucket_server_side_encryption_configuration.alb_logs
  ]
}
