################################################################################
# Secret
################################################################################

output "secret_arn" {
  description = "The ARN of the secret"
  value       = try(aws_secretsmanager_secret.this[0].arn, null)
}

output "secret_id" {
  description = "The ID of the secret"
  value       = try(aws_secretsmanager_secret.this[0].id, null)
}

output "secret_name" {
  description = "The name of the secret"
  value       = try(aws_secretsmanager_secret.this[0].name, null)
}

output "secret_replica" {
  description = "Attributes of the replica created"
  value       = try(aws_secretsmanager_secret.this[0].replica, null)
}

################################################################################
# Secret Version
################################################################################

output "secret_version_id" {
  description = "The unique identifier of the version of the secret"
  value       = try(aws_secretsmanager_secret_version.this[0].version_id, aws_secretsmanager_secret_version.ignoreChanges[0].version_id, null)
}

output "secret_string" {
  description = "The secret string"
  sensitive   = true
  value       = try(aws_secretsmanager_secret_version.this[0].secret_string, aws_secretsmanager_secret_version.ignoreChanges[0].secret_string, null)
}

output "secret_binary" {
  description = "The secret binary"
  sensitive   = true
  value       = try(aws_secretsmanager_secret_version.this[0].secret_binary, aws_secretsmanager_secret_version.ignoreChanges[0].secret_binary, null)
}

output "secret_string_wo_version" {
  description = "The version number of the write-only secret string (`secret_string_wo`). The write-only value itself is never exposed"
  value       = try(aws_secretsmanager_secret_version.this[0].secret_string_wo_version, aws_secretsmanager_secret_version.ignoreChanges[0].secret_string_wo_version, null)
}

output "has_secret_string_wo" {
  description = "Whether the secret value was stored using the write-only `secret_string_wo` argument"
  value       = try(aws_secretsmanager_secret_version.this[0].has_secret_string_wo, aws_secretsmanager_secret_version.ignoreChanges[0].has_secret_string_wo, null)
}

output "secret_version_stages" {
  description = "The list of staging labels attached to this version of the secret"
  value       = try(aws_secretsmanager_secret_version.this[0].version_stages, aws_secretsmanager_secret_version.ignoreChanges[0].version_stages, null)
}

################################################################################
# Rotation
################################################################################

output "rotation_enabled" {
  description = "Whether rotation is enabled for this secret"
  value       = length(aws_secretsmanager_secret_rotation.this) > 0
}
