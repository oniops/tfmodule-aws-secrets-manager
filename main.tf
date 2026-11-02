locals {
  tags = merge(try(var.context.tags, {}), var.tags)

  # count must not depend on secret values: they may be unknown until apply (e.g. attributes of resources created in the same run).
  create_version = var.create && var.create_secret_version

  # secret_string_wo is ephemeral, so secret_string_wo_version (always set together with it) is checked instead.
  has_secret_value = var.secret_string != null || var.secret_binary != null || var.secret_string_wo_version != null
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
  count          = local.create_version && !var.ignore_secret_changes ? 1 : 0
  secret_id      = aws_secretsmanager_secret.this[0].id
  secret_binary  = var.secret_binary
  secret_string  = var.secret_string
  version_stages = var.version_stages

  # Write-only: the value is sent to AWS but never persisted in plan or state.
  secret_string_wo         = var.secret_string_wo
  secret_string_wo_version = var.secret_string_wo_version

  lifecycle {
    precondition {
      condition     = local.has_secret_value
      error_message = "One of secret_string, secret_binary or secret_string_wo must be set. To create the secret without a value, set create_secret_version = false."
    }
  }
}

resource "aws_secretsmanager_secret_version" "ignoreChanges" {
  count          = local.create_version && var.ignore_secret_changes ? 1 : 0
  secret_id      = aws_secretsmanager_secret.this[0].id
  secret_binary  = var.secret_binary
  secret_string  = var.secret_string
  version_stages = var.version_stages

  # Write-only: the value is sent to AWS but never persisted in plan or state.
  secret_string_wo         = var.secret_string_wo
  secret_string_wo_version = var.secret_string_wo_version

  lifecycle {
    precondition {
      condition     = local.has_secret_value
      error_message = "One of secret_string, secret_binary or secret_string_wo must be set. To create the secret without a value, set create_secret_version = false."
    }

    ignore_changes = [
      secret_string,
      secret_binary,
      secret_string_wo_version,
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

  # Rotation (especially rotate_immediately) requires an AWSCURRENT version to exist first.
  depends_on = [
    aws_secretsmanager_secret_version.this,
    aws_secretsmanager_secret_version.ignoreChanges,
  ]
}
