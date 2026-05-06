variable "context" {
  description = "Specify context values. This module uses the tfmodule-context Terraform module to define Secrets Manager services and resources, providing a standardized naming policy and tagging conventions, and a consistent datasource reference module. For more information about Context, see the https://github.com/oniops/tfmodule-context Terraform module."
  type        = any
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = <<EOF
Specify tags for resources created in this module.

Example)
  tags = {
    "ExpirationDate"  = "20260102"
    "PurposeOfUse"    = "PoC"
  }
EOF
}

variable "create" {
  description = "Determines whether Secrets Manager resources will be created"
  type        = bool
  default     = true
}

variable "name" {
  description = "Human-readable name of the secret"
  type        = string
}

variable "description" {
  description = "A description of the secret"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "ARN or Id of the AWS KMS key to be used to encrypt the secret values in the versions stored in this secret. If you need to reference a CMK in a different account, you can use only the key ARN. If you don't specify this value, then Secrets Manager defaults to using the AWS account's default KMS key (the one named `aws/secretsmanager`)"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret. This value can be `0` to force deletion without recovery or range from `7` to `30` days. The default value is `30`"
  type        = number
  default     = null
}

variable "force_overwrite_replica_secret" {
  description = "Accepts boolean value to specify whether to overwrite a secret with the same name in the destination Region"
  type        = bool
  default     = null
}

variable "replica" {
  description = "Configuration block to support secret replication"
  type = map(object({
    kms_key_id = optional(string)
    region     = optional(string)
  }))
  default = null
}

variable "create_policy" {
  description = "Determines whether a resource policy will be created for the secret"
  type        = bool
  default     = false
}

variable "block_public_policy" {
  description = "Makes an optional API call to Zelkova to validate the Resource Policy to prevent broad access to your secret"
  type        = bool
  default     = null
}

variable "policy" {
  type    = any
  default = []
  description = <<EOF
List of IAM policy statements for the secret resource policy. Statements must have unique `sid`s.

Example)
  policy = [
    {
      Sid       = "AllowCrossAccountRoleAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::111122223333:role/my-role" }
      Action    = ["secretsmanager:GetSecretValue"]
      Resource  = "*"
    }
  ]
EOF
}

variable "ignore_secret_changes" {
  description = "Determines whether or not Terraform will ignore changes made externally to `secret_string` or `secret_binary`. Changing this value after creation is a destructive operation"
  type        = bool
  default     = false
}

variable "secret_binary" {
  description = "Specifies binary data that you want to encrypt and store in this version of the secret. This is required if `secret_string` is not set. Needs to be encoded to base64"
  type        = string
  default     = null
}

variable "secret_string" {
  description = "Specifies text data that you want to encrypt and store in this version of the secret. This is required if `secret_binary` is not set"
  type        = string
  default     = null
}

variable "version_stages" {
  description = "Specifies a list of staging labels that are attached to this version of the secret. A staging label must be unique to a single version of the secret"
  type        = list(string)
  default     = null
}

variable "enable_rotation" {
  description = "Determines whether secret rotation is enabled"
  type        = bool
  default     = false
}

variable "rotate_immediately" {
  description = "Specifies whether to rotate the secret immediately or wait until the next scheduled rotation window. The rotation schedule is defined in `rotation_rules`"
  type        = bool
  default     = null
}

variable "rotation_lambda_arn" {
  description = "Specifies the ARN of the Lambda function that can rotate the secret"
  type        = string
  default     = null
}

variable "rotation_rules" {
  description = "A structure that defines the rotation configuration for this secret"
  type = object({
    automatically_after_days = optional(number)
    duration                 = optional(string)
    schedule_expression      = optional(string)
  })
  default = null
}
