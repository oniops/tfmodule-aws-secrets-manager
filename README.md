# tfmodule-aws-secrets-manager

tfmodule-aws-secrets-manager is a Terraform module which creates AWS Secrets Manager resources.

## How to clone

```sh
git clone https://github.com/oniops/tfmodule-aws-secrets-manager.git
cd tfmodule-aws-secrets-manager
```

## Context

This module uses the tfmodule-context Terraform module to define Secrets Manager services and resources, providing a standardized naming policy and tagging conventions for AWS Best Practice model, and a consistent datasource reference module.
<br>
For more information about Context, see the [tfmodule-context](https://github.com/oniops/tfmodule-context) Terraform module.

## Usage

### Example 1 : Basic Secret

This chapter explains how to create a basic secret.

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-api-key"
  secret_string = jsonencode({
    username = "admin"
    password = "s3cr3t!"
  })
}

output "secret_arn" {
  value = module.secret.secret_arn
}
```

<br>

### Example 2 : Secret with Cross-Account Access Policy

This chapter explains how to allow an IAM Role from another AWS account (`111122223333`) to retrieve the secret using `policy`.

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-api-key"
  secret_string = jsonencode({
    api_key = "abc123"
  })

  create_policy = true
  policy = [
    {
      Sid    = "AllowCrossAccountRoleAccess"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::111122223333:role/my-cross-account-role"
      }
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-*"
    }
  ]
}
```

<br>

### Example 3 : Secret with Rotation

This chapter explains how to enable automatic secret rotation using a Lambda function. Since the rotation Lambda manages the secret value after creation, `ignore_secret_changes` must be set to `true` to prevent Terraform from overwriting the Lambda-managed value on the next `terraform apply`. See [Using Rotation with `ignore_secret_changes`](#using-rotation-with-ignore_secret_changes) in the Appendix for details.

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-db-password"
  secret_string = jsonencode({
    username = "dbadmin"
    password = "initialPassword!"
  })

  enable_rotation       = true
  ignore_secret_changes = true
  rotation_lambda_arn   = "arn:aws:lambda:ap-northeast-2:111122223333:function:my-rotation-lambda"
  rotation_rules = {
    automatically_after_days = 30
  }
}

output "rotation_enabled" {
  value = module.secret.rotation_enabled
}
```

<br>

### Example 4 : Secret with Ignore Changes

This chapter explains how to create a secret that Terraform manages only on initial creation. After creation, changes to the secret value made externally (via AWS Console, CLI, or other tools) are preserved and not overwritten by Terraform.

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-externally-managed-secret"

  # Set an initial value at creation time
  secret_string = jsonencode({
    password = "initialValue"
  })

  # Terraform will not overwrite external changes after creation
  ignore_secret_changes = true
}
```

<br>

### Example 5 : Secret with KMS Encryption

This chapter explains how to encrypt a secret using a customer-managed KMS key instead of the default AWS-managed key (`aws/secretsmanager`).

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-encrypted-secret"
  secret_string = jsonencode({
    token = "my-secure-token"
  })

  kms_key_id = "arn:aws:kms:ap-northeast-2:111122223333:key/012ab345-ab12-3344-a556-112233445566"
}
```

<br>

> **Note:** If the secret value is changed outside Terraform (e.g., via AWS Console, CLI, or a rotation Lambda without `ignore_secret_changes = true`), the active secret version may no longer match the version tracked in Terraform state. For guidance on how to handle this, see [Syncing Externally Changed Secret Values](#syncing-externally-changed-secret-values) in the Appendix.

## Variables

This chapter describes Input/Output variables used in tfmodule-aws-secrets-manager.

### Input Variables

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Default</th>
        <th>Required</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>context</td>
        <td>Specify context values. This module uses the tfmodule-context Terraform module to define Secrets Manager services and resources, providing a standardized naming policy and tagging conventions, and a consistent datasource reference module. For more information about Context, see the <a href="https://github.com/oniops/tfmodule-context">tfmodule-context</a> Terraform module.</td>
        <td>any</td>
        <td></td>
        <td>yes</td>
        <td><pre>{
  project     = "demo"
  region      = "ap-northeast-2"
  environment = "Development"
  department  = "DevOps"
  owner       = "my_devops_team@example.com"
  customer    = "Example Customer"
  domain      = "example.com"
  pri_domain  = "example.internal"
}</pre></td>
    </tr>
    <tr>
        <td>tags</td>
        <td>Specify tags for resources created in this module.</td>
        <td>map(string)</td>
        <td>{}</td>
        <td>no</td>
        <td><pre>{
  ExpirationDate = "20260102"
  PurposeOfUse   = "PoC"
}</pre></td>
    </tr>
    <tr>
        <td>create</td>
        <td>Determines whether Secrets Manager resources will be created.</td>
        <td>bool</td>
        <td>true</td>
        <td>no</td>
        <td>false</td>
    </tr>
</tbody>
</table>

#### Secret

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Default</th>
        <th>Required</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>name</td>
        <td>Human-readable name of the secret.</td>
        <td>string</td>
        <td></td>
        <td>yes</td>
        <td>"my-api-key"</td>
    </tr>
    <tr>
        <td>description</td>
        <td>A description of the secret.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"API key for external service"</td>
    </tr>
    <tr>
        <td>kms_key_id</td>
        <td>ARN or Id of the AWS KMS key to encrypt secret values. If not specified, Secrets Manager uses the default AWS-managed key (<code>aws/secretsmanager</code>).</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"arn:aws:kms:ap-northeast-2:111122223333:key/012ab345-ab12-3344-a556-112233445566"</td>
    </tr>
    <tr>
        <td>recovery_window_in_days</td>
        <td>Number of days AWS Secrets Manager waits before deleting the secret. Set to <code>0</code> to force immediate deletion, or between <code>7</code> and <code>30</code> days. Default is 30.</td>
        <td>number</td>
        <td>null</td>
        <td>no</td>
        <td>7</td>
    </tr>
    <tr>
        <td>force_overwrite_replica_secret</td>
        <td>Whether to overwrite a secret with the same name in the destination Region during replication.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>replica</td>
        <td>Configuration block to support secret replication to other AWS regions. The map key is used as the region if <code>region</code> is not specified in the value.</td>
        <td>map(object)</td>
        <td>null</td>
        <td>no</td>
        <td><pre>{
  "us-east-1" = {
    kms_key_id = "arn:aws:kms:us-east-1:111122223333:key/..."
  }
}</pre></td>
    </tr>
</tbody>
</table>

#### Secret Policy

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Default</th>
        <th>Required</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>create_policy</td>
        <td>Determines whether a resource policy will be created for the secret.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>block_public_policy</td>
        <td>Makes an optional API call to Zelkova to validate the Resource Policy to prevent broad access to the secret.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>policy</td>
        <td>List of IAM policy statements for the secret resource policy. Statements must have unique <code>sid</code>s.</td>
        <td>any</td>
        <td>[]</td>
        <td>no</td>
        <td><pre>[
  {
    Sid    = "AllowCrossAccountRoleAccess"
    Effect = "Allow"
    Principal = {
      AWS = "arn:aws:iam::111122223333:role/my-role"
    }
    Action   = ["secretsmanager:GetSecretValue"]
    Resource = "arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-*"
  }
]</pre></td>
    </tr>
</tbody>
</table>

#### Secret Version

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Default</th>
        <th>Required</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>ignore_secret_changes</td>
        <td>When <code>true</code>, Terraform ignores external changes to <code>secret_string</code> or <code>secret_binary</code> after initial creation. Changing this value after creation is a destructive operation. Use when the secret value is managed outside Terraform.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>secret_string</td>
        <td>Plaintext data to encrypt and store. Required if <code>secret_binary</code> is not set. Use <code>jsonencode()</code> to store structured data.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"{\"username\":\"admin\",\"password\":\"s3cr3t\"}"</td>
    </tr>
    <tr>
        <td>secret_binary</td>
        <td>Binary data to encrypt and store, encoded to base64. Required if <code>secret_string</code> is not set.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"dGVzdA=="</td>
    </tr>
    <tr>
        <td>version_stages</td>
        <td>List of staging labels attached to this version of the secret. Each staging label must be unique to a single version.</td>
        <td>list(string)</td>
        <td>null</td>
        <td>no</td>
        <td>["AWSCURRENT"]</td>
    </tr>
</tbody>
</table>

#### Rotation

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Default</th>
        <th>Required</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>enable_rotation</td>
        <td>Determines whether automatic secret rotation is enabled. When using rotation, it is strongly recommended to also set <code>ignore_secret_changes = true</code> to prevent Terraform from overwriting rotation-managed values.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>rotation_lambda_arn</td>
        <td>ARN of the Lambda function that rotates the secret. Required when <code>enable_rotation</code> is <code>true</code>.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"arn:aws:lambda:ap-northeast-2:111122223333:function:my-rotation-fn"</td>
    </tr>
    <tr>
        <td>rotate_immediately</td>
        <td>Whether to rotate the secret immediately upon enabling rotation. If <code>false</code>, rotation occurs at the next scheduled window.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>false</td>
    </tr>
    <tr>
        <td>rotation_rules</td>
        <td>Rotation schedule configuration. Specify either <code>automatically_after_days</code> or <code>schedule_expression</code>, not both.</td>
        <td>object</td>
        <td>null</td>
        <td>no</td>
        <td><pre>{
  automatically_after_days = 30
}
or
{
  schedule_expression = "rate(30 days)"
  duration            = "3h"
}</pre></td>
    </tr>
</tbody>
</table>

### Output Variables

<table>
<thead>
    <tr>
        <th>Name</th>
        <th>Description</th>
        <th>Type</th>
        <th>Example</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>secret_arn</td>
        <td>The ARN of the secret.</td>
        <td>string</td>
        <td>"arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-AbCdEf"</td>
    </tr>
    <tr>
        <td>secret_id</td>
        <td>The ID of the secret (same as ARN).</td>
        <td>string</td>
        <td>"arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-AbCdEf"</td>
    </tr>
    <tr>
        <td>secret_name</td>
        <td>The name of the secret.</td>
        <td>string</td>
        <td>"my-api-key"</td>
    </tr>
    <tr>
        <td>secret_replica</td>
        <td>Attributes of the replica created.</td>
        <td>any</td>
        <td></td>
    </tr>
    <tr>
        <td>secret_version_id</td>
        <td>The unique identifier of the version of the secret.</td>
        <td>string</td>
        <td>"terraform-20260101000000000000000001"</td>
    </tr>
    <tr>
        <td>secret_string</td>
        <td>The secret string. Sensitive value.</td>
        <td>string (sensitive)</td>
        <td>"{\"username\":\"admin\",\"password\":\"s3cr3t\"}"</td>
    </tr>
    <tr>
        <td>secret_binary</td>
        <td>The secret binary. Sensitive value.</td>
        <td>string (sensitive)</td>
        <td>"dGVzdA=="</td>
    </tr>
    <tr>
        <td>secret_version_stages</td>
        <td>The list of staging labels attached to this version of the secret.</td>
        <td>list(string)</td>
        <td>["AWSCURRENT"]</td>
    </tr>
    <tr>
        <td>rotation_enabled</td>
        <td>Whether rotation is enabled for this secret.</td>
        <td>bool</td>
        <td>true</td>
    </tr>
</tbody>
</table>

# Appendix

## AWS Secrets Manager Overview

AWS Secrets Manager is a fully managed service that helps you protect access to your applications, services, and IT resources. It enables you to securely store, retrieve, and automatically rotate secrets such as database credentials, API keys, and OAuth tokens.
<br>
For more information: [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)

### Secret Versioning

Secrets Manager maintains a version history for each secret. Each version holds a copy of the encrypted secret value and is identified by a version ID and staging labels.

| Staging Label | Description |
|---|---|
| `AWSCURRENT` | The current active version of the secret |
| `AWSPREVIOUS` | The previous version, retained after rotation |
| `AWSPENDING` | The version being prepared during rotation |

### Terraform and Secret Values (`ignore_secret_changes`)

By default, Terraform manages the secret value and will overwrite external changes on `terraform apply`. Use `ignore_secret_changes = true` when the secret value is managed outside Terraform (e.g., manually via Console/CLI, or by a rotation Lambda).

| Setting | Value managed by | Terraform behavior |
|---|---|---|
| `ignore_secret_changes = false` (default) | **Terraform** | Updates secret value on plan/apply |
| `ignore_secret_changes = true` | **External (Console, CLI, Lambda)** | Ignores value changes after creation |

### Encryption

Secrets Manager encrypts secret values at rest using AWS KMS.

| Method | Description | Variable |
|---|---|---|
| AWS-managed key | Uses the default `aws/secretsmanager` key. No additional cost for key management | (default, no variable needed) |
| Customer-managed key (CMK) | Uses a customer-managed KMS key. Fine-grained control over key access policies | `kms_key_id = "<key-arn>"` |

## Using Rotation with `ignore_secret_changes`

When `enable_rotation = true`, the rotation Lambda automatically updates the secret value on a schedule. However, enabling rotation does **not** automatically suppress Terraform from managing the secret version. If `ignore_secret_changes` is not set to `true`, Terraform will overwrite the Lambda-managed value with the original `secret_string` on the next `terraform apply`.

**It is strongly recommended to set `ignore_secret_changes = true` whenever `enable_rotation = true` is used.**

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-db-password"
  secret_string = jsonencode({
    username = "dbadmin"
    password = "initialPassword!"
  })

  enable_rotation       = true
  ignore_secret_changes = true  # prevents Terraform from overwriting rotation-managed values
  rotation_lambda_arn   = "arn:aws:lambda:ap-northeast-2:111122223333:function:my-rotation-lambda"
  rotation_rules = {
    automatically_after_days = 30
  }
}
```

## Syncing Externally Changed Secret Values

When a secret value is changed outside Terraform (via AWS Console, CLI, or another tool), AWS creates a **new secret version** and moves the `AWSCURRENT` label to it. Terraform's state still references the previous version ID, which remains in AWS but is no longer the active version. Because the old version still exists, `terraform plan` will not detect a drift and no immediate overwrite occurs. However, if the old version is eventually cleaned up by AWS, or if Terraform is triggered to recreate the version resource (e.g., due to a change in `secret_string`), Terraform will use the original value from the configuration, discarding the externally-set value.

To proactively sync Terraform state with the externally-changed value, follow these steps:

**Step 1.** Retrieve the current (AWSCURRENT) version ID from AWS.

```bash
aws secretsmanager list-secret-version-ids \
  --secret-id <secret-arn-or-name> \
  --query 'Versions[?contains(VersionStages, `AWSCURRENT`)].[VersionId]' \
  --output text
```

**Step 2.** Remove the outdated version resource from Terraform state.

```bash
# If ignore_secret_changes = false (default)
terraform state rm 'module.<module_name>.aws_secretsmanager_secret_version.this[0]'

# If ignore_secret_changes = true
terraform state rm 'module.<module_name>.aws_secretsmanager_secret_version.ignoreChanges[0]'
```

**Step 3.** *(Required only when `ignore_secret_changes = false`)* Update `secret_string` in your Terraform configuration to match the new value. This prevents Terraform from detecting a drift and recreating the version with the old value after import. If `ignore_secret_changes = true`, this step can be skipped because Terraform ignores `secret_string` changes after the initial creation.

**Step 4.** Import the new version into Terraform state.

```bash
# If ignore_secret_changes = false (default)
terraform import \
  'module.<module_name>.aws_secretsmanager_secret_version.this[0]' \
  '<secret-arn>|<new-version-id>'

# If ignore_secret_changes = true
terraform import \
  'module.<module_name>.aws_secretsmanager_secret_version.ignoreChanges[0]' \
  '<secret-arn>|<new-version-id>'
```

**Step 5.** Verify no changes are planned.

```bash
terraform plan
```

> **Tip:** If the secret value is expected to change externally on a regular basis, consider setting `ignore_secret_changes = true` from the start to avoid this synchronization process entirely.

# LICENSE

- See [LICENSE](https://github.com/oniops/tfmodule-aws-secrets-manager/blob/main/LICENSE) for Apache-2.0.
