# ============================================
# AWS Backup Vault
# ============================================

resource "aws_backup_vault" "main" {
  count = var.enable_backup ? 1 : 0

  name        = "${local.name_prefix}-backup-vault"
  kms_key_arn = aws_kms_key.main.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-backup-vault"
    }
  )
}

# ============================================
# AWS Backup Plan
# ============================================

resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0

  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }

    recovery_point_tags = merge(
      local.common_tags,
      {
        BackupPlan = "${local.name_prefix}-backup-plan"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-backup-plan"
    }
  )
}

# ============================================
# Backup Selection
# ============================================

resource "aws_backup_selection" "main" {
  count = var.enable_backup ? 1 : 0

  name         = "${local.name_prefix}-backup-selection"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = [
    aws_instance.dev_server.arn
  ]

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = var.project_name
  }
}

# ============================================
# Backup IAM Role
# ============================================

resource "aws_iam_role" "backup" {
  count = var.enable_backup ? 1 : 0

  name_prefix = "${local.name_prefix}-backup-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-backup-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
