locals {
  create_policy = var.create && var.create_policy && length(var.policy) > 0

  policy = local.create_policy ? {
    Version   = "2012-10-17"
    Statement = var.policy
  } : null
}

resource "aws_secretsmanager_secret_policy" "this" {
  count               = local.create_policy ? 1 : 0
  block_public_policy = var.block_public_policy
  policy              = jsonencode(local.policy)
  secret_arn          = aws_secretsmanager_secret.this[0].arn
}
