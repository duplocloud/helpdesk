# Terraform reference

Operations guide for the Terraform in this directory: architecture, naming, database options, security
controls, outputs and troubleshooting. To deploy, start with the [top-level README](../README.md); every
input variable is documented in [docs/VARIABLES.md](../docs/VARIABLES.md).

## Architecture

```
Root Module
├── modules/vpc           — VPC, subnets (public/private ×3 AZs), IGW, NAT GW, route tables
├── modules/eks           — EKS control plane, OIDC provider, managed node group, IAM roles, SGs (cluster/nodes/ALB)
├── modules/eks-addons    — ALB Controller, EFS CSI, EBS CSI (managed addon), External DNS, Backend S3 IRSA
├── modules/s3            — ai-studio + ai-studio-userdata buckets with encryption
├── modules/efs           — EFS filesystem, mount targets, NFS security group
├── modules/documentdb    — Optional AWS DocumentDB cluster (only when database_backend = "documentdb")
├── modules/eks-storage   — Kubernetes StorageClasses: ai-studio-efs (EFS) + gp3 (EBS)
├── modules/acm           — ACM certificate (DNS-validated via Route53) for helpdesk + xterm hostnames
└── modules/helm-ai-studio — duplo-ai-helpdesk Helm release + rendered values.yml
```


## Resource Naming

All AWS resources follow a semantic naming pattern based on the `prefix` variable (default: `"duplo-ai"`):

**Pattern**: `<prefix>-<resource-type>`

Example with default `prefix = "duplo-ai"`:
- VPC: `duplo-ai-vpc`
- EKS cluster: `duplo-ai-eks`
- Security groups: `duplo-ai-eks-cluster-sg`, `duplo-ai-eks-node-sg`, `duplo-ai-alb-sg`
- EFS: `duplo-ai-efs`
- Subnets: `duplo-ai-public-a`, `duplo-ai-private-b`, etc.
- IAM roles: `duplo-ai-eks-alb-controller-role`, `duplo-ai-backend-s3-role`
- EKS node group: `duplo-ai-eks-duplo-ai-ng` (EC2 instances inherit this name)
- DocumentDB: `duplo-ai-docdb`, `duplo-ai-docdb-instance-1`
- **Kubernetes namespace: `duplo-ai` (always, regardless of prefix)**

Custom prefix example (`prefix = "acme"`):
- VPC: `acme-vpc`
- EKS cluster: `acme-eks`
- All other resources follow the same pattern
- **Kubernetes namespace: `duplo-ai` (always the same)**

S3 buckets use the AWS account ID:
- `ai-studio-<account_id>` (e.g., `ai-studio-123456789012`)
- With optional suffix: `ai-studio-<account_id>-<suffix>`

Set your `prefix` in `terraform.tfvars` to customize resource names for your deployment.

Worker nodes run in **private subnets**. Public subnets host only the NAT Gateway and ALB. All add-ons use IRSA (IAM Roles for Service Accounts) for least-privilege AWS access. External DNS automatically creates Route53 A records from ingress annotations.

## Database backend

`database_backend` selects where Helpdesk stores its data:

| Value | What gets deployed |
|-------|--------------------|
| `mongodb` (default) | The chart's bundled MongoDB StatefulSet on an EBS `gp3` volume, plus the chart's nightly `mongodump` backup CronJob. No extra AWS resources. |
| `documentdb` | A managed AWS DocumentDB cluster (`modules/documentdb`). Recommended for production; billed separately by AWS and adds ~10–15 minutes to apply. |

With `documentdb`, Terraform creates:

- a DocumentDB subnet group across the VPC's private subnets
- a security group that accepts port 27017 **only** from the worker node security groups
- the cluster (encrypted storage, engine `5.0.0`, 7-day automated backups, final snapshot on destroy) and `documentdb_instance_count` instance(s)
- a generated master password stored in Secrets Manager as `<prefix>-documentdb-master` (`documentdb_master_secret_arn` output)

The Helm values are then rendered with `mongodb.enabled: false` and `secrets.mongoDbConnectionString`, so no in-cluster MongoDB, Service, backup CronJob, or mongodump PVC is created. `mongodb_root_password` isn't needed in this mode.

```hcl
database_backend               = "documentdb"
documentdb_instance_count      = 2    # optional HA
documentdb_deletion_protection = true # optional, recommended for production
```

> **TLS note:** the connection string uses `tls=true&retryWrites=false&tlsInsecure=true`. DocumentDB requires TLS and doesn't support retryable writes. `tlsInsecure=true` is needed because the backend image doesn't trust Amazon's DocumentDB CA and the chart can't mount a CA bundle yet. Traffic is still encrypted, and the security group limits who can reach the cluster, but the certificate isn't verified.

> **Switching backends on an existing deployment doesn't migrate data.** Moving `mongodb` → `documentdb` starts with an empty database, and the bundled MongoDB StatefulSet and its PVC are removed from the release. Run `mongodump`/`mongorestore` yourself before switching if you need to keep the data.

## Security & compliance controls (SOC2)

Every deployment gets these controls by default:

| Control | Where | Details |
|---|---|---|
| VPC flow logs (ALL traffic) | `modules/vpc` | CloudWatch log group `/aws/vpc/<prefix>-vpc/flow-logs`, `log_retention_days` retention |
| Default security group denies all | `modules/vpc` | `aws_default_security_group` with no rules. Nothing in this stack uses it |
| Default network ACL blocks public remote admin | `modules/vpc` | Denies inbound TCP 22 (SSH) and 3389 (RDP) from `0.0.0.0/0`; allows everything else |
| EKS control plane audit logging | `modules/eks` | `api`, `audit`, `authenticator` → `/aws/eks/<prefix>-eks/cluster`, `log_retention_days` retention |
| S3 versioning | `modules/s3` | Both `ai-studio-*` buckets; noncurrent versions expire after `s3_noncurrent_version_expiration_days` |
| S3 HTTPS-only | `modules/s3` | Bucket policy denies any request where `aws:SecureTransport` is `false` |
| Worker-node CPU alarm | `modules/monitoring` | On the node group's Auto Scaling Group (`AutoScalingGroupName` dimension), so it survives node replacement |
| ALB alarms | `modules/monitoring` | Target response time, 5xx (ELB + target), unhealthy hosts across all target groups (Metrics Insights query) |
| Alarm notifications | `modules/monitoring` | SNS topic `<prefix>-helpdesk-alerts` (`alerts_sns_topic_arn` output) |

**Subscribe personnel to the alerts topic yourself.** Terraform creates the topic but no subscriptions:

```bash
aws sns subscribe --topic-arn "$(terraform output -raw alerts_sns_topic_arn)" \
  --protocol email --notification-endpoint oncall@example.com   # then confirm the email
```

The ALB is created by the AWS Load Balancer Controller rather than by Terraform, so on the first apply the
`monitoring` module waits up to 10 minutes for it (AWS CLI calls, using `aws_profile`/`aws_region`) and
finds it by its controller tags.

The Terraform **state bucket and lock table** are created outside this configuration. If you keep state in S3
(`backend.tf.example`), apply the same controls to the bucket and lock table:

```bash
aws s3api put-bucket-versioning --bucket <state-bucket> --versioning-configuration Status=Enabled
aws s3api put-bucket-policy --bucket <state-bucket> --policy '{"Version":"2012-10-17","Statement":[{"Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::<state-bucket>","arn:aws:s3:::<state-bucket>/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}'
aws dynamodb update-continuous-backups --table-name <lock-table> \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

Not covered here: WAF on the ALB, and restricting the ALB security group's HTTP/HTTPS ingress (it stays open
to the internet so the portal is reachable; HTTP only redirects to HTTPS).

## Outputs

| Output | Description |
|--------|-------------|
| `helpdesk_url` | Helpdesk URL |
| `helpdesk_xterm_url` | Helpdesk xterm URL |
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `nat_gateway_ip` | NAT Gateway public IP |
| `eks_cluster_name` | EKS cluster name |
| `eks_cluster_endpoint` | EKS API endpoint |
| `eks_cluster_security_group_id` | Cluster SG ID |
| `kubeconfig_command` | kubectl config command |
| `s3_bucket_name` | Main S3 bucket name |
| `s3_bucket_arn` | Main S3 bucket ARN |
| `s3_userdata_bucket_name` | Userdata S3 bucket name |
| `efs_id` | EFS filesystem ID |
| `acm_certificate_arn` | ACM certificate ARN |
| `alb_sg_id` | ALB security group ID |
| `alb_controller_role_arn` | ALB Controller IAM role ARN |
| `efs_csi_role_arn` | EFS CSI IAM role ARN |
| `external_dns_role_arn` | External DNS IAM role ARN |
| `helpdesk_analytics_collector_irsa_role_arn` | Helpdesk analytics collector IRSA role ARN |
| `helm_ai_studio_status` | Helm release deployment status |
| `alerts_sns_topic_arn` | SNS topic for alarm notifications (add subscriptions to it) |
| `monitoring_alarm_names` | CloudWatch alarms created for SOC2 monitoring |
| `database_backend` | Database backend in use (`mongodb` or `documentdb`) |
| `documentdb_endpoint` | DocumentDB cluster endpoint (`null` for `mongodb`) |
| `documentdb_master_secret_arn` | Secrets Manager ARN with the DocumentDB master credentials (`null` for `mongodb`) |
| `documentdb_security_group_id` | DocumentDB security group ID (`null` for `mongodb`) |

## Destroy

```bash
terraform destroy
```

> **Note:** The S3 state bucket is not managed by this configuration and must be deleted manually.
>
> With `database_backend = "documentdb"`, destroy takes a final snapshot `<prefix>-docdb-final` unless `documentdb_skip_final_snapshot = true`. That snapshot is kept after destroy — delete it by hand before destroying the same cluster name again, or the second destroy fails because the snapshot name is already taken. If `documentdb_deletion_protection = true`, set it to `false` and apply before you destroy.

## Troubleshooting

**Node group creation fails with IAM error**
IAM propagation can lag. Run `terraform apply` a second time.

**kubectl token expired**
Re-run: `aws eks update-kubeconfig --region <region> --name <cluster_name>`

**Helm provider can't reach cluster**
Ensure your workstation can reach the EKS endpoint. The cluster has `endpoint_public_access = true`.

**ALB health checks failing / 504 errors**
- Verify the EKS-managed cluster SG has ingress from the ALB SG (all TCP, 0–65535). The `aws_security_group_rule.cluster_sg_from_alb` resource handles this, but check it exists in state.
- With `target-type: ip`, ALB routes to pod IPs and the evaluated SG is the EKS-managed cluster SG (not the custom node SG). The custom `-node-sg` is irrelevant for ALB health checks.
- The `success-codes: "200-404"` annotation is required because the backend returns 404 at `/`.

**MongoDB pod stuck in Init or CrashLoopBackOff (EFS mount)**
MongoDB's WiredTiger storage engine requires POSIX file locking which NFS/EFS doesn't support. The values template hardcodes `storageClass: gp3` (EBS) for MongoDB — ensure the `gp3` EBS StorageClass exists and the EBS CSI addon is healthy.

**EFS mounts timing out**
The EFS SG must allow NFS (2049/tcp) from the EKS-managed cluster SG (`eks-cluster-sg-*`), not just the custom node SG. EKS managed node groups only attach the cluster SG to instances.

**ACM certificate stuck in PENDING_VALIDATION**
External DNS must be running and Route53 zone must be publicly accessible. Check: `kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns`

**Helm release timeout (context deadline exceeded)**
The `helm_release.ai_studio` has `timeout = 900`. If it still times out, check pod events: `kubectl describe pods` and `kubectl get events --sort-by=.lastTimestamp`
