# Module: s3

Creates an S3 bucket named `ai-studio-<account_id>` with AES256 server-side encryption, public access blocked, and optional lifecycle expiration.

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `account_id` | string | yes | — | AWS account ID (used in bucket name) |
| `lifecycle_enabled` | bool | no | `false` | Enable lifecycle expiration rule |
| `lifecycle_expiration_days` | number | no | `90` | Days until objects expire |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |

## Notes

- Versioning is intentionally disabled per spec.
- Encryption uses AES256 (SSE-S3). Switch to `aws:kms` by editing the `sse_algorithm` if KMS is preferred.
- Public access is fully blocked via all four `aws_s3_bucket_public_access_block` settings.
