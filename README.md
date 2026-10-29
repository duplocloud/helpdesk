# DuploCloud AI Helpdesk on AWS

Terraform that deploys [DuploCloud AI Helpdesk](https://duplocloud.com) into your own AWS account with a
single `terraform apply`. You provide AWS credentials, a hostname in a Route53 zone you own, and a Google
OAuth client; Terraform builds everything else and gives you a working HTTPS URL.

## What gets deployed

- A VPC across 3 Availability Zones (public and private subnets, NAT gateway)
- An Amazon EKS cluster with 2 worker nodes in private subnets
- An internet-facing Application Load Balancer with an ACM TLS certificate, and DNS records in your
  Route53 zone, both managed automatically
- Storage: EFS for application data, encrypted EBS for MongoDB, two encrypted S3 buckets
- The Helpdesk application (Helm chart `oci://quay.io/duplocloud/helpdesk`), using Amazon Bedrock
  (Anthropic Claude) for AI features
- Audit logging (VPC flow logs, EKS control-plane logs) and CloudWatch alarms with an SNS topic

Architecture details: [terraform/README.md](terraform/README.md).

## Before you start

You need:

1. **An AWS account** and credentials with administrator access (the stack creates IAM roles, a VPC,
   EKS and more). Any method the AWS CLI supports works: a named profile, SSO, or environment variables.
2. **A public Route53 hosted zone** in that account for the domain you'll use, e.g. `example.com` for
   `helpdesk.example.com`. If your domain is registered elsewhere, delegate a subdomain to Route53 first.
3. **A Google OAuth client** for sign-in (Helpdesk has no local passwords). In Google Cloud Console →
   *APIs & Services* → *Credentials* → *Create credentials* → *OAuth client ID* → *Web application*:
   - Authorized JavaScript origin: `https://helpdesk.example.com`
   - Authorized redirect URI: `https://helpdesk.example.com/signin-google`

   Microsoft Entra ID works too; see [docs/VARIABLES.md](docs/VARIABLES.md#6-sign-in-providers).
4. **Tools** on the machine that runs Terraform:

   | Tool | Version |
   |---|---|
   | [Terraform](https://developer.hashicorp.com/terraform/install) | 1.5 or newer |
   | [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 (also used by Terraform during apply) |
   | [kubectl](https://kubernetes.io/docs/tasks/tools/) | optional, for inspecting the cluster |

5. **A region with Amazon Bedrock Claude models**, e.g. `us-east-1` or `us-west-2`. The deployment
   accepts the model agreements for you.

## Quick start

```bash
git clone -b aws https://github.com/duplocloud/helpdesk.git
cd helpdesk/terraform

cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. This is all that's required:

```hcl
aws_region           = "us-east-1"
helpdesk_dns         = "helpdesk.example.com"
google_client_id     = "1234-abc.apps.googleusercontent.com"
google_client_secret = "GOCSPX-..."
auth_super_users     = "you@example.com"   # recommended: your admin account
```

Then deploy:

```bash
export AWS_PROFILE=my-profile   # or any other way of providing AWS credentials

terraform init
terraform apply
```

The first apply takes about 25 minutes. When it finishes:

```bash
terraform output helpdesk_url
```

Give the pods a few more minutes to start and DNS to propagate, then open the URL and sign in with
Google. Accounts listed in `auth_super_users` get admin rights.

To check progress:

```bash
$(terraform output -raw kubeconfig_command)
kubectl get pods -n duplo-ai
```

## Configuration

Every variable, its default and what changing it does: **[docs/VARIABLES.md](docs/VARIABLES.md)**.

Things that are handled for you unless you override them:

- The xterm hostname (`helpdesk-xterm.example.com`) and the Route53 zone are derived from `helpdesk_dns`.
- The JWT secret and MongoDB password are generated randomly.
- External DNS only touches the zone that holds `helpdesk_dns`.

## Terraform state and secrets

State is kept in a local `terraform.tfstate` file by default. It contains the generated secrets and
everything Terraform needs to update or destroy the stack, so **don't lose it and don't commit it**
(it is gitignored). For anything long-lived, move it to S3:

```bash
cp backend.tf.example backend.tf   # edit bucket/key/region
terraform init -migrate-state
```

## Telemetry

The analytics collector is enabled by default. It sends product usage and billing reports for this
Helpdesk instance to the DuploCloud control plane (`controlplane.prod-apps.duplocloud.net`), identified by
`helpdesk_analytics_collector_app_instance` and an IAM role in your account. To opt out:

```hcl
helpdesk_analytics_collector_enabled = false
```

## Cost

With the defaults, expect roughly **$250/month** in `us-east-1` before Bedrock usage: EKS control plane,
two `t3a.large` nodes, a NAT gateway, an ALB, plus small amounts of EFS, EBS, S3 and CloudWatch. Bedrock
model usage is billed per token on top. `database_backend = "documentdb"` adds DocumentDB instance costs.
Check current pricing for your region.

## Removing everything

```bash
terraform destroy
```

If you used `database_backend = "documentdb"`, a final snapshot is kept after destroy; see
[terraform/README.md](terraform/README.md#destroy).

## Troubleshooting

See [terraform/README.md#troubleshooting](terraform/README.md#troubleshooting). Common first-run issues:

- **`no matching Route53Zone found`:** the hosted zone doesn't exist in this account, or the derived name
  is wrong; set `route53_zone_name` explicitly.
- **Google says `redirect_uri_mismatch`:** the redirect URI in the Google client must be exactly
  `https://<helpdesk_dns>/signin-google`.
- **`InvalidParameter` errors on plan or destroy (e.g. `GetTopicAttributes ... Invalid parameter: TopicArn`):**
  `aws_region` was changed while resources still exist in the old region. Set it back, run
  `terraform destroy`, then switch regions.
- **Apply fails partway through with an IAM or timeout error:** run `terraform apply` again; it picks up
  where it stopped.
