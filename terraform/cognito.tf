# ============================================
# Cognito User Pool
# ============================================

resource "aws_cognito_user_pool" "main" {
  name = var.cognito_user_pool_name

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Auto-verify email
  auto_verified_attributes = ["email"]

  # MFA configuration (optional)
  mfa_configuration = "OPTIONAL"

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = merge(
    local.common_tags,
    {
      Name = var.cognito_user_pool_name
    }
  )
}

# ============================================
# Cognito User Pool Client
# ============================================

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth configuration for ALB
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback URLs (ALB will use these)
  callback_urls = [
    "https://${local.domain_name}/oauth2/idpresponse"
  ]

  logout_urls = [
    "https://${local.domain_name}"
  ]

  supported_identity_providers = ["COGNITO"]

  # Token validity
  refresh_token_validity = 30
  access_token_validity  = 60
  id_token_validity      = 60

  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read/write attributes
  read_attributes  = ["email", "email_verified"]
  write_attributes = ["email"]
}

# ============================================
# Cognito User Pool Domain
# ============================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# ============================================
# Optional: Create Admin User
# ============================================

resource "aws_cognito_user" "admin" {
  count = var.create_cognito_admin_user && var.cognito_admin_email != "" ? 1 : 0

  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.cognito_admin_email

  attributes = {
    email          = var.cognito_admin_email
    email_verified = true
  }

  # User will receive temporary password via email
  message_action = "SUPPRESS" # or "RESEND" to send email

  lifecycle {
    ignore_changes = [
      attributes,
      message_action
    ]
  }
}
