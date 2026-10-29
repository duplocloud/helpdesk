# Module: eks-addons

Deploys three EKS add-ons via Helm, each with a dedicated IAM role using IRSA:

- **AWS Load Balancer Controller** — provisions ALB/NLB for Kubernetes Ingress/Service resources
- **EFS CSI Driver** — enables EFS-backed persistent volumes
- **External DNS** — automatically manages Route53 records from Kubernetes resources

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `cluster_name` | string | yes | — | EKS cluster name |
| `oidc_provider_arn` | string | yes | — | OIDC provider ARN |
| `oidc_provider_url` | string | yes | — | OIDC provider URL (no `https://`) |
| `vpc_id` | string | yes | — | VPC ID |
| `external_dns_domain_filter` | string | no | `""` | Restrict External DNS to a domain |
| `alb_controller_chart_version` | string | no | `1.7.1` | Helm chart version |
| `efs_csi_chart_version` | string | no | `2.5.6` | Helm chart version |
| `external_dns_chart_version` | string | no | `1.14.3` | Helm chart version |

## Outputs

| Name | Description |
|------|-------------|
| `alb_controller_role_arn` | ALB Controller IAM role ARN |
| `efs_csi_role_arn` | EFS CSI IAM role ARN |
| `external_dns_role_arn` | External DNS IAM role ARN |

## Notes

- The ALB Controller IAM policy is fetched directly from the official upstream URL.
- All service accounts use IRSA — no static credentials are stored in the cluster.
- This module depends on `module.eks` being fully applied first.
