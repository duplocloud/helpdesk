# Terraform variables

Every input the stack accepts, grouped by how likely you are to need it. Set values in
`terraform/terraform.tfvars` (start from [`terraform.tfvars.example`](../terraform/terraform.tfvars.example)).

AWS credentials are **not** Terraform variables. Terraform, the Helm/Kubernetes providers and the
AWS CLI calls made during apply all use your standard AWS credential chain: `AWS_PROFILE`,
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, SSO, or `aws_profile` below.

- [1. Required](#1-required)
- [2. Recommended](#2-recommended)
- [3. Derived or generated automatically](#3-derived-or-generated-automatically)
- [4. Common options](#4-common-options)
- [5. Database](#5-database)
- [6. Sign-in providers](#6-sign-in-providers)
- [7. Analytics collector](#7-analytics-collector)
- [8. Slack integration](#8-slack-integration)
- [9. Advanced](#9-advanced)
- [Changing variables after the first apply](#changing-variables-after-the-first-apply)

---

## 1. Required

The smallest working `terraform.tfvars`:

```hcl
aws_region           = "us-east-1"
helpdesk_dns         = "helpdesk.example.com"
google_client_id     = "1234-abc.apps.googleusercontent.com"
google_client_secret = "GOCSPX-..."
```

| Variable | Type | Description |
|---|---|---|
| `aws_region` | `string` | AWS region to deploy into. Pick a region where Amazon Bedrock offers Anthropic Claude models (for example `us-east-1`, `us-west-2`). |
| `helpdesk_dns` | `string` | Public hostname users open, e.g. `helpdesk.example.com`. Lowercase, no `https://`, no trailing dot. **Its public Route53 hosted zone must already exist in the same AWS account** — Terraform validates the TLS certificate and External DNS creates the record in that zone. |
| `google_client_id` | `string`, sensitive | Google OAuth client ID. Required while `google_oauth_enabled = true` (the default). See [Sign-in providers](#6-sign-in-providers). |
| `google_client_secret` | `string`, sensitive | Google OAuth client secret. Same rule as above. |

Helpdesk has no local username/password login: at least one OAuth provider (Google by default, or
Microsoft) must be configured, otherwise nobody can sign in.

## 2. Recommended

| Variable | Type | Default | Description |
|---|---|---|---|
| `auth_super_users` | `string` | `""` | Comma-separated email addresses that get super-user (admin) rights once they sign in, e.g. `"alice@example.com,bob@example.com"`. Set at least your own address. |
| `aws_profile` | `string` | `""` | Named AWS CLI profile. Empty = default credential chain. Recommended for long applies so short-lived session credentials don't expire mid-run. |

## 3. Derived or generated automatically

Leave these unset unless you need a specific value. Setting one explicitly always wins.

| Variable | Default when unset | Description |
|---|---|---|
| `route53_zone_name` | `helpdesk_dns` minus its first label (`helpdesk.example.com` → `example.com`) | Public Route53 hosted zone holding the Helpdesk records. Set it when the zone is higher up, e.g. `helpdesk.dev.example.com` in zone `example.com`. |
| `helpdesk_xterm_dns` | `<first label>-xterm.<rest>` (`helpdesk-xterm.example.com`) | Hostname for the browser terminal (xterm) service. Must be in the same hosted zone. Covered by the same TLS certificate. |
| `external_dns_domain_filter` | the hosted zone above | Zones External DNS may change. `""` lets it manage **every** hosted zone in the account (not recommended in shared accounts). |
| `jwt_shared_secret` | random 64-character string | Secret used to sign session tokens. Changing it signs every user out. |
| `mongodb_root_password` | random 32-character string | Root password of the in-cluster MongoDB (`database_backend = "mongodb"` only). Set it only on the first apply: changing it later does not change the password inside the existing database. |
| `helpdesk_analytics_collector_app_instance` | `<prefix>-<account_id>-<aws_region>` | Identifier the analytics collector reports. Must be unique per Helpdesk deployment within a cloud environment; the default already is unless you reuse a prefix in the same account and region. |

Generated secrets are stored in Terraform state (see [Changing variables](#changing-variables-after-the-first-apply)
and the README section on state).

## 4. Common options

| Variable | Type | Default | Description |
|---|---|---|---|
| `prefix` | `string` | `"duplo-ai"` | Prefix for AWS resource names: `<prefix>-vpc`, `<prefix>-eks`, `<prefix>-efs`, IAM roles, alarms, … 1–20 chars, lowercase letters, digits and hyphens, starting with a letter. Use different prefixes to run several deployments in one account. The Kubernetes namespace is always `duplo-ai`. |
| `node_instance_type` | `string` | `"t3a.large"` | EC2 instance type for EKS worker nodes. |
| `node_desired` | `number` | `2` | Number of worker nodes. |
| `node_min` | `number` | `2` | Minimum size of the node group. |
| `node_max` | `number` | `2` | Maximum size of the node group. No cluster autoscaler is installed, so the group stays at `node_desired`; raise `node_desired` to add nodes. |
| `node_disk_size` | `number` | `20` | Root volume size (GiB) per node. |
| `common_tags` | `map(string)` | `{}` | Tags added to every AWS resource that supports tags. |
| `s3_bucket_name_suffix` | `string` | `""` | Buckets are named `ai-studio-<account_id>` and `ai-studio-userdata-<account_id>`. Set a suffix (2–31 lowercase chars) to run a second deployment in the same account: `ai-studio-<account_id>-<suffix>`. |

## 5. Database

| Variable | Type | Default | Description |
|---|---|---|---|
| `database_backend` | `string` | `"mongodb"` | `"mongodb"`: MongoDB runs inside the cluster on an encrypted EBS volume, with a nightly `mongodump` backup to EFS. No extra AWS cost. `"documentdb"`: a managed Amazon DocumentDB cluster in the private subnets; recommended for production, billed separately, adds ~10–15 min to apply. |
| `documentdb_instance_class` | `string` | `"db.t3.medium"` | DocumentDB instance size. |
| `documentdb_instance_count` | `number` | `1` | 1–16. Two or more add failover replicas in other AZs. |
| `documentdb_engine_version` | `string` | `"5.0.0"` | DocumentDB engine version. |
| `documentdb_backup_retention_period` | `number` | `7` | Days of automated backups, 1–35. |
| `documentdb_deletion_protection` | `bool` | `false` | Blocks deletion of the cluster. Set `true` for production (and back to `false` before `terraform destroy`). |
| `documentdb_skip_final_snapshot` | `bool` | `false` | When `false`, destroy keeps a final snapshot `<prefix>-docdb-final`. |

With `documentdb`, the master password is generated and stored in AWS Secrets Manager
(`<prefix>-documentdb-master`, see the `documentdb_master_secret_arn` output).

Switching `database_backend` on an existing deployment does **not** migrate data.

## 6. Sign-in providers

### Google (default)

| Variable | Type | Default | Description |
|---|---|---|---|
| `google_oauth_enabled` | `bool` | `true` | Enable "Sign in with Google". When `true`, `google_client_id` and `google_client_secret` must be set (checked at plan time). |
| `google_client_id` | `string`, sensitive | `""` | OAuth 2.0 client ID. |
| `google_client_secret` | `string`, sensitive | `""` | OAuth 2.0 client secret. |

Create the client in Google Cloud Console → *APIs & Services* → *Credentials* → *Create credentials*
→ *OAuth client ID*, application type **Web application**:

- **Authorized JavaScript origin:** `https://<helpdesk_dns>`
- **Authorized redirect URI:** `https://<helpdesk_dns>/signin-google`

If the OAuth consent screen is set to *Internal*, only accounts in your Google Workspace can sign in.

### Microsoft Entra ID (optional)

| Variable | Type | Default | Description |
|---|---|---|---|
| `microsoft_oauth_enabled` | `bool` | `false` | Enable "Sign in with Microsoft". When `true`, the three values below are required. |
| `microsoft_client_id` | `string`, sensitive | `""` | App registration (client) ID. |
| `microsoft_client_secret` | `string`, sensitive | `""` | Client secret value. |
| `microsoft_tenant_id` | `string` | `""` | `"common"` for any Microsoft account, or your tenant GUID to restrict sign-in to one organization. |

To use Microsoft only, also set `google_oauth_enabled = false`.

## 7. Analytics collector

| Variable | Type | Default | Description |
|---|---|---|---|
| `helpdesk_analytics_collector_enabled` | `bool` | `true` | Runs the analytics collector, which sends product usage and billing reports to the DuploCloud control plane (`controlplane.prod-apps.duplocloud.net`). Set `false` to opt out. |
| `helpdesk_analytics_collector_app_instance` | `string` | derived | See [section 3](#3-derived-or-generated-automatically). |

## 8. Slack integration

Optional. Leave disabled unless you have a Slack app set up for Helpdesk.

| Variable | Type | Default | Description |
|---|---|---|---|
| `slack_backend_enabled` | `bool` | `false` | Deploy the Slack backend. |
| `slack_backend_image_tag` | `string` | `""` | Slack backend image tag. |
| `slack_app_token` | `string`, sensitive | `""` | Slack app-level token (`xapp-…`). |
| `slack_bot_token` | `string`, sensitive | `""` | Slack bot token (`xoxb-…`). |
| `slack_app_portals` | `string`, sensitive | `""` | Portal configuration, as a JSON string. |
| `slack_helpdesk_default_agent` | `string` | `""` | Default Helpdesk agent for Slack conversations. |
| `slack_helpdesk_default_workspace` | `string` | `""` | Default Helpdesk workspace for Slack conversations. |

## 9. Advanced

### Cluster and network

| Variable | Type | Default | Description |
|---|---|---|---|
| `kubernetes_version` | `string` | `null` | EKS version, e.g. `"1.33"`. `null` = the EKS default version at creation time. |
| `node_ami_type` | `string` | `"AL2023_x86_64_STANDARD"` | EKS managed node group AMI type. Use an `ARM_64` type only with a Graviton `node_instance_type`. |
| `vpc_cidr` | `string` | `null` (`10.0.0.0/16`) | VPC CIDR. Six /24 subnets (3 public, 3 private) are carved from it, so use a /16–/20. Change it if you will peer with a network using `10.0.0.0/16`. |
| `helm_ai_studio_chart_version` | `string` | `"0.2.24"` | Version of the `oci://quay.io/duplocloud/helpdesk` Helm chart. |

### S3

| Variable | Type | Default | Description |
|---|---|---|---|
| `s3_lifecycle_enabled` | `bool` | `false` | Expire current objects in the main `ai-studio-*` bucket after `s3_lifecycle_expiration_days`. |
| `s3_lifecycle_expiration_days` | `number` | `90` | Used only when `s3_lifecycle_enabled = true`. |
| `s3_noncurrent_version_expiration_days` | `number` | `90` | Days to keep old (overwritten/deleted) object versions in both buckets. |

### Logging and alarms

| Variable | Type | Default | Description |
|---|---|---|---|
| `log_retention_days` | `number` | `365` | CloudWatch retention for VPC flow logs and EKS control-plane logs. |
| `alarm_cpu_threshold_percent` | `number` | `80` | Alarm when average worker-node CPU is above this for 15 minutes. |
| `alarm_alb_response_time_threshold_seconds` | `number` | `10` | Alarm when average load balancer response time is above this (3 of 5 minutes). AI-backed requests are slow by nature, so keep it generous. |
| `alarm_alb_5xx_threshold_count` | `number` | `10` | Alarm when 5xx responses reach this many in 5 minutes. |

Alarms notify the SNS topic in the `alerts_sns_topic_arn` output. Terraform creates no subscriptions —
add an email or paging endpoint yourself (see the README).

---

## Changing variables after the first apply

| Variable | Effect of changing it later |
|---|---|
| `aws_region` | **Don't change it on a live deployment.** Terraform keeps looking for the existing resources in the new region and plan/destroy fail (e.g. `InvalidParameter: TopicArn`). Run `terraform destroy` first, then change the region and apply. |
| `prefix`, `vpc_cidr` | Replaces the whole stack (new VPC, cluster, database). Treat as a new deployment. |
| `helpdesk_dns`, `helpdesk_xterm_dns` | New TLS certificate and DNS records; update the OAuth redirect URI too. |
| `database_backend` | Starts with an empty database; no data migration. |
| `mongodb_root_password` | Does not change the password of an existing MongoDB volume. Don't change it after the first apply. |
| `jwt_shared_secret` | Signs every user out. |
| `node_instance_type`, `node_disk_size`, `node_ami_type` | Replaces the worker nodes (pods are rescheduled). |
| `node_desired`, `node_min`, `node_max` | Resizes the node group in place. |
| `s3_bucket_name_suffix` | Creates new, empty buckets. |

`terraform.tfvars` and Terraform state both contain secrets. Keep `terraform.tfvars` out of version
control (it is gitignored) and store state somewhere access-controlled; see `terraform/backend.tf.example`.
