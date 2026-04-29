# tfmodule-aws-secrets-manager

tfmodule-aws-secrets-manager는 AWS Secrets Manager 리소스를 생성하는 Terraform 모듈입니다.

## How to clone

```sh
git clone https://github.com/oniops/tfmodule-aws-secrets-manager.git
cd tfmodule-aws-secrets-manager
```

## Context

이 모듈은 tfmodule-context Terraform 모듈을 사용하여 Secrets Manager 서비스 및 리소스를 정의합니다. AWS Best Practice 모델에 따른 표준화된 네이밍 정책과 태그 규칙, 일관된 데이터소스 참조 모듈을 제공합니다.
<br>
Context에 대한 자세한 내용은 [tfmodule-context](https://github.com/oniops/tfmodule-context) Terraform 모듈을 참고하세요.

## 사용법

### 예제 1 : 기본 시크릿

기본적인 시크릿을 생성하는 방법을 설명합니다.

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

### 예제 2 : 타 계정 IAM Role 접근 허용 시크릿

`policy`를 사용하여 다른 AWS 계정(`111122223333`)의 IAM Role이 시크릿에 접근할 수 있도록 허용하는 방법을 설명합니다.

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

### 예제 3 : 자동 교체(Rotation) 시크릿

Lambda 함수를 사용하여 시크릿을 자동으로 교체하는 방법을 설명합니다. Rotation Lambda가 시크릿 값을 관리하기 때문에, `ignore_secret_changes = true`를 설정하지 않으면 다음 `terraform apply` 시 Terraform이 Lambda가 교체한 값을 `secret_string`의 값으로 덮어쓸 수 있습니다. 자세한 내용은 부록의 [Rotation 사용 시 ignore_secret_changes 권장](#rotation-사용-시-ignore_secret_changes-권장)을 참고하세요.

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

### 예제 4 : 외부 변경 무시 시크릿

Terraform이 초기 생성 시에만 시크릿 값을 관리하고, 이후 AWS 콘솔, CLI, 또는 기타 도구로 변경된 값을 Terraform이 덮어쓰지 않도록 설정하는 방법을 설명합니다.

```hcl
module "secret" {
  source  = "git::https://github.com/oniops/tfmodule-aws-secrets-manager.git?ref=v1.0.0"
  context = module.ctx.context
  name    = "my-externally-managed-secret"

  # 초기 생성 시 값 설정
  secret_string = jsonencode({
    password = "initialValue"
  })

  # 생성 이후 외부에서 변경된 값을 Terraform이 덮어쓰지 않음
  ignore_secret_changes = true
}
```

<br>

### 예제 5 : KMS 암호화 시크릿

기본 AWS 관리형 키(`aws/secretsmanager`) 대신 고객 관리형 KMS 키를 사용하여 시크릿을 암호화하는 방법을 설명합니다.

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

> **Note:** AWS 콘솔, CLI, 또는 `ignore_secret_changes = true` 없이 Rotation Lambda를 사용하는 경우, 시크릿 값이 Terraform 외부에서 변경되면 활성 버전이 Terraform state에서 추적하는 버전과 달라질 수 있습니다. 이 경우 처리 방법은 부록의 [외부에서 변경된 시크릿 값 동기화](#외부에서-변경된-시크릿-값-동기화)를 참고하세요.

## 변수

tfmodule-aws-secrets-manager에서 사용되는 입력/출력 변수를 설명합니다.

### 입력 변수

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>기본값</th>
        <th>필수</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>context</td>
        <td>Context 값을 지정합니다. 이 모듈은 tfmodule-context Terraform 모듈을 사용하여 Secrets Manager 서비스 및 리소스를 정의하며, 표준화된 네이밍 정책, 태그 규칙, 일관된 데이터소스 참조 모듈을 제공합니다. Context에 대한 자세한 내용은 <a href="https://github.com/oniops/tfmodule-context">tfmodule-context</a> Terraform 모듈을 참고하세요.</td>
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
        <td>이 모듈에서 생성되는 리소스에 태그를 지정합니다.</td>
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
        <td>Secrets Manager 리소스 생성 여부를 결정합니다.</td>
        <td>bool</td>
        <td>true</td>
        <td>no</td>
        <td>false</td>
    </tr>
</tbody>
</table>

#### 시크릿 (Secret)

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>기본값</th>
        <th>필수</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>name</td>
        <td>시크릿의 이름입니다.</td>
        <td>string</td>
        <td></td>
        <td>yes</td>
        <td>"my-api-key"</td>
    </tr>
    <tr>
        <td>description</td>
        <td>시크릿에 대한 설명입니다.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"외부 서비스 API 키"</td>
    </tr>
    <tr>
        <td>kms_key_id</td>
        <td>시크릿 값을 암호화하는 데 사용할 AWS KMS 키의 ARN 또는 ID입니다. 지정하지 않으면 Secrets Manager가 기본 AWS 관리형 키(<code>aws/secretsmanager</code>)를 사용합니다.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"arn:aws:kms:ap-northeast-2:111122223333:key/012ab345-ab12-3344-a556-112233445566"</td>
    </tr>
    <tr>
        <td>recovery_window_in_days</td>
        <td>AWS Secrets Manager가 시크릿을 삭제하기 전에 대기하는 일수입니다. <code>0</code>으로 설정하면 즉시 삭제되며, <code>7</code>~<code>30</code>일 사이의 값으로 설정할 수 있습니다. 기본값은 30일입니다.</td>
        <td>number</td>
        <td>null</td>
        <td>no</td>
        <td>7</td>
    </tr>
    <tr>
        <td>force_overwrite_replica_secret</td>
        <td>복제 대상 리전에 동일한 이름의 시크릿이 존재할 경우 덮어쓸지 여부를 지정합니다.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>replica</td>
        <td>다른 AWS 리전으로 시크릿을 복제하기 위한 설정 블록입니다. 맵의 키는 <code>region</code>이 지정되지 않은 경우 리전으로 사용됩니다.</td>
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

#### 시크릿 정책 (Secret Policy)

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>기본값</th>
        <th>필수</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>create_policy</td>
        <td>시크릿에 대한 리소스 기반 정책 생성 여부를 결정합니다.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>block_public_policy</td>
        <td>Zelkova API를 호출하여 시크릿에 대한 광범위한 접근을 방지하도록 리소스 정책을 검증합니다.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>policy</td>
        <td>시크릿 리소스 정책에 사용할 IAM 정책 구문 목록입니다. 구문에는 고유한 <code>sid</code>가 있어야 합니다.</td>
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

#### 시크릿 버전 (Secret Version)

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>기본값</th>
        <th>필수</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>ignore_secret_changes</td>
        <td><code>true</code>로 설정하면 초기 생성 이후 <code>secret_string</code> 또는 <code>secret_binary</code>에 대한 외부 변경을 Terraform이 무시합니다. 생성 이후 이 값을 변경하는 것은 파괴적인 작업입니다. 시크릿 값을 Terraform 외부에서 관리할 때 사용합니다.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>secret_string</td>
        <td>암호화하여 저장할 평문 데이터입니다. <code>secret_binary</code>가 설정되지 않은 경우 필수입니다. 구조화된 데이터를 저장하려면 <code>jsonencode()</code>를 사용하세요.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"{\"username\":\"admin\",\"password\":\"s3cr3t\"}"</td>
    </tr>
    <tr>
        <td>secret_binary</td>
        <td>base64로 인코딩된 바이너리 데이터입니다. <code>secret_string</code>이 설정되지 않은 경우 필수입니다.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"dGVzdA=="</td>
    </tr>
    <tr>
        <td>version_stages</td>
        <td>이 버전의 시크릿에 연결된 스테이징 레이블 목록입니다. 각 스테이징 레이블은 하나의 버전에만 연결될 수 있습니다.</td>
        <td>list(string)</td>
        <td>null</td>
        <td>no</td>
        <td>["AWSCURRENT"]</td>
    </tr>
</tbody>
</table>

#### 자동 교체 (Rotation)

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>기본값</th>
        <th>필수</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>enable_rotation</td>
        <td>시크릿 자동 교체 활성화 여부를 결정합니다. Rotation을 사용할 때는 <code>ignore_secret_changes = true</code>를 함께 설정하여 Terraform이 Rotation Lambda가 관리하는 값을 덮어쓰지 않도록 하는 것을 강력히 권장합니다.</td>
        <td>bool</td>
        <td>false</td>
        <td>no</td>
        <td>true</td>
    </tr>
    <tr>
        <td>rotation_lambda_arn</td>
        <td>시크릿을 교체하는 Lambda 함수의 ARN입니다. <code>enable_rotation</code>이 <code>true</code>인 경우 필수입니다.</td>
        <td>string</td>
        <td>null</td>
        <td>no</td>
        <td>"arn:aws:lambda:ap-northeast-2:111122223333:function:my-rotation-fn"</td>
    </tr>
    <tr>
        <td>rotate_immediately</td>
        <td>Rotation 활성화 시 즉시 교체할지 여부입니다. <code>false</code>로 설정하면 다음 예약된 시간에 교체됩니다.</td>
        <td>bool</td>
        <td>null</td>
        <td>no</td>
        <td>false</td>
    </tr>
    <tr>
        <td>rotation_rules</td>
        <td>Rotation 일정 설정입니다. <code>automatically_after_days</code> 또는 <code>schedule_expression</code> 중 하나만 지정해야 합니다.</td>
        <td>object</td>
        <td>null</td>
        <td>no</td>
        <td><pre>일 단위 교체:
{
  automatically_after_days = 30
}
Rate 표현식 교체:
{
  schedule_expression = "rate(30 days)"
  duration            = "3h"
}</pre></td>
    </tr>
</tbody>
</table>

### 출력 변수

<table>
<thead>
    <tr>
        <th>이름</th>
        <th>설명</th>
        <th>타입</th>
        <th>예시</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>secret_arn</td>
        <td>시크릿의 ARN입니다.</td>
        <td>string</td>
        <td>"arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-AbCdEf"</td>
    </tr>
    <tr>
        <td>secret_id</td>
        <td>시크릿의 ID입니다 (ARN과 동일).</td>
        <td>string</td>
        <td>"arn:aws:secretsmanager:ap-northeast-2:111122223333:secret:my-api-key-AbCdEf"</td>
    </tr>
    <tr>
        <td>secret_name</td>
        <td>시크릿의 이름입니다.</td>
        <td>string</td>
        <td>"my-api-key"</td>
    </tr>
    <tr>
        <td>secret_replica</td>
        <td>생성된 복제본의 속성입니다.</td>
        <td>any</td>
        <td></td>
    </tr>
    <tr>
        <td>secret_version_id</td>
        <td>시크릿 버전의 고유 식별자입니다.</td>
        <td>string</td>
        <td>"terraform-20260101000000000000000001"</td>
    </tr>
    <tr>
        <td>secret_string</td>
        <td>시크릿 문자열 값입니다. 민감한 값(Sensitive)입니다.</td>
        <td>string (sensitive)</td>
        <td>"{\"username\":\"admin\",\"password\":\"s3cr3t\"}"</td>
    </tr>
    <tr>
        <td>secret_binary</td>
        <td>시크릿 바이너리 값입니다. 민감한 값(Sensitive)입니다.</td>
        <td>string (sensitive)</td>
        <td>"dGVzdA=="</td>
    </tr>
    <tr>
        <td>secret_version_stages</td>
        <td>이 버전의 시크릿에 연결된 스테이징 레이블 목록입니다.</td>
        <td>list(string)</td>
        <td>["AWSCURRENT"]</td>
    </tr>
    <tr>
        <td>rotation_enabled</td>
        <td>이 시크릿에 대해 Rotation이 활성화되어 있는지 여부입니다.</td>
        <td>bool</td>
        <td>true</td>
    </tr>
</tbody>
</table>

# 부록

## AWS Secrets Manager 개요

AWS Secrets Manager는 데이터베이스 자격 증명, API 키, OAuth 토큰 등의 시크릿을 안전하게 저장, 조회, 자동 교체할 수 있게 해주는 완전 관리형 서비스입니다. 애플리케이션, 서비스, IT 리소스에 대한 접근을 보호하는 데 도움을 줍니다.
<br>
자세한 내용은 문서를 참고하세요 : [AWS Secrets Manager](https://docs.aws.amazon.com/ko_kr/secretsmanager/latest/userguide/intro.html)

### 시크릿 버전 관리

Secrets Manager는 각 시크릿의 버전 히스토리를 관리합니다. 각 버전은 암호화된 시크릿 값의 복사본을 보유하며, 버전 ID와 스테이징 레이블로 식별됩니다.

| 스테이징 레이블 | 설명 |
|---|---|
| `AWSCURRENT` | 현재 활성 버전 |
| `AWSPREVIOUS` | 교체 이후 보관되는 이전 버전 |
| `AWSPENDING` | Rotation 중 준비되는 버전 |

### Terraform과 시크릿 값 (`ignore_secret_changes`)

기본적으로 Terraform은 시크릿 값을 관리하며, `terraform apply` 시 외부 변경을 덮어씁니다. 시크릿 값이 Terraform 외부(콘솔, CLI, Rotation Lambda 등)에서 관리되는 경우 `ignore_secret_changes = true`를 사용하세요.

| 설정 | 값 관리 주체 | Terraform 동작 |
|---|---|---|
| `ignore_secret_changes = false` (기본값) | **Terraform** | plan/apply 시 시크릿 값 업데이트 |
| `ignore_secret_changes = true` | **외부 (콘솔, CLI, Lambda)** | 생성 이후 값 변경 무시 |

### 암호화

Secrets Manager는 저장된 시크릿 값을 AWS KMS를 사용하여 암호화합니다.

| 방식 | 설명 | 변수 |
|---|---|---|
| AWS 관리형 키 | 기본 `aws/secretsmanager` 키를 사용합니다. 키 관리 추가 비용 없음 | (기본값, 별도 설정 불필요) |
| 고객 관리형 키 (CMK) | 고객 관리형 KMS 키를 사용합니다. 키 접근 정책을 세밀하게 제어할 수 있습니다 | `kms_key_id = "<key-arn>"` |

## Rotation 사용 시 `ignore_secret_changes` 권장

`enable_rotation = true`로 설정하면 Rotation Lambda가 스케줄에 따라 자동으로 시크릿 값을 교체합니다. 그러나 Rotation을 활성화한다고 해서 Terraform이 시크릿 버전 관리를 자동으로 멈추지는 않습니다. `ignore_secret_changes = true`를 설정하지 않으면, 다음 `terraform apply` 시 Terraform이 Lambda가 교체한 값을 `secret_string`에 정의된 초기값으로 덮어써버립니다.

**`enable_rotation = true`를 사용할 때는 반드시 `ignore_secret_changes = true`를 함께 설정하는 것을 강력히 권장합니다.**

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
  ignore_secret_changes = true  # Rotation Lambda가 관리하는 값을 Terraform이 덮어쓰지 않도록 설정
  rotation_lambda_arn   = "arn:aws:lambda:ap-northeast-2:111122223333:function:my-rotation-lambda"
  rotation_rules = {
    automatically_after_days = 30
  }
}
```

## 외부에서 변경된 시크릿 값 동기화

AWS 콘솔, CLI, 또는 다른 도구를 통해 Terraform 외부에서 시크릿 값이 변경되면, AWS는 **새 시크릿 버전**을 생성하고 `AWSCURRENT` 레이블을 새 버전으로 이동시킵니다. Terraform state는 여전히 이전 버전 ID를 참조하고 있으며, 이전 버전은 AWS에 남아있지만 더 이상 활성 버전이 아닙니다. 이전 버전이 AWS에 존재하는 동안은 `terraform plan`에서 drift가 감지되지 않으므로 즉각적인 덮어쓰기는 발생하지 않습니다. 그러나 AWS가 이전 버전을 정리하거나, Terraform이 버전 리소스를 재생성하게 되는 변경이 발생하면(예: `secret_string` 변경), Terraform은 설정 파일의 원래 값을 사용하게 되어 외부에서 설정한 값이 사라질 수 있습니다.

Terraform state를 외부에서 변경된 값과 사전에 동기화하려면 아래 절차를 따르세요.

**Step 1.** AWS에서 현재(AWSCURRENT) 버전 ID를 확인합니다.

```bash
aws secretsmanager list-secret-version-ids \
  --secret-id <secret-arn-or-name> \
  --query 'Versions[?contains(VersionStages, `AWSCURRENT`)].[VersionId]' \
  --output text
```

**Step 2.** Terraform state에서 기존 버전 리소스를 제거합니다.

```bash
# ignore_secret_changes = false (기본값) 인 경우
terraform state rm 'module.<module_name>.aws_secretsmanager_secret_version.this[0]'

# ignore_secret_changes = true 인 경우
terraform state rm 'module.<module_name>.aws_secretsmanager_secret_version.ignoreChanges[0]'
```

**Step 3.** *(`ignore_secret_changes = false`인 경우에만 필요)* Terraform 설정 파일의 `secret_string` 값을 외부에서 변경된 새 값으로 업데이트합니다. import 이후 Terraform이 이전 값으로 버전을 재생성하려는 것을 방지하기 위함입니다. `ignore_secret_changes = true`인 경우, Terraform이 초기 생성 이후 `secret_string` 변경을 무시하므로 이 단계는 생략할 수 있습니다.

**Step 4.** 새 버전을 Terraform state에 import합니다.

```bash
# ignore_secret_changes = false (기본값) 인 경우
terraform import \
  'module.<module_name>.aws_secretsmanager_secret_version.this[0]' \
  '<secret-arn>|<new-version-id>'

# ignore_secret_changes = true 인 경우
terraform import \
  'module.<module_name>.aws_secretsmanager_secret_version.ignoreChanges[0]' \
  '<secret-arn>|<new-version-id>'
```

**Step 5.** 변경 사항이 없는지 확인합니다.

```bash
terraform plan
```

> **Tip:** 시크릿 값이 외부에서 정기적으로 변경될 것으로 예상된다면, 처음부터 `ignore_secret_changes = true`를 설정하여 이 동기화 과정 자체를 생략하는 것을 고려하세요.

# 라이선스

- Apache-2.0 라이선스는 [LICENSE](https://github.com/oniops/tfmodule-aws-secrets-manager/blob/main/LICENSE)를 참고하세요.
