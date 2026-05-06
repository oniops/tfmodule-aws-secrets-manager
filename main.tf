locals {
  tags = merge(var.context.tags, var.tags)
}

resource "aws_secretsmanager_secret" "this" {
  count                          = var.create ? 1 : 0
  description                    = var.description
  force_overwrite_replica_secret = var.force_overwrite_replica_secret
  kms_key_id                     = var.kms_key_id
  name                           = var.name
  recovery_window_in_days        = var.recovery_window_in_days

  dynamic "replica" {
    for_each = var.replica != null ? var.replica : {}
    content {
      kms_key_id = replica.value.kms_key_id
      region     = coalesce(replica.value.region, replica.key)
    }
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "aws_secretsmanager_secret_version" "this" {
  count          = var.create && !var.ignore_secret_changes ? 1 : 0
  secret_id      = aws_secretsmanager_secret.this[0].id
  secret_binary  = var.secret_binary
  secret_string  = var.secret_string
  version_stages = var.version_stages
}

resource "aws_secretsmanager_secret_version" "ignoreChanges" {
  count          = var.create && var.ignore_secret_changes ? 1 : 0
  secret_id      = aws_secretsmanager_secret.this[0].id
  secret_binary  = var.secret_binary
  secret_string  = var.secret_string
  version_stages = var.version_stages

  lifecycle {
    ignore_changes = [
      secret_string,
      secret_binary,
      version_stages,
    ]
  }
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count               = var.create && var.enable_rotation ? 1 : 0
  secret_id           = aws_secretsmanager_secret.this[0].id
  rotate_immediately  = var.rotate_immediately
  rotation_lambda_arn = var.rotation_lambda_arn

  dynamic "rotation_rules" {
    for_each = var.rotation_rules != null ? [var.rotation_rules] : []
    content {
      automatically_after_days = rotation_rules.value.automatically_after_days
      duration                 = rotation_rules.value.duration
      schedule_expression      = rotation_rules.value.schedule_expression
    }
  }
}
