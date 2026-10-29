# Module: eks

Deploys an EKS control plane, OIDC identity provider (for IRSA), IAM roles for the cluster and worker nodes, security groups, and a managed node group in private subnets.

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `cluster_name` | string | yes | — | EKS cluster name |
| `kubernetes_version` | string | no | latest | Pin Kubernetes version (e.g. `"1.29"`) |
| `vpc_id` | string | yes | — | VPC ID |
| `private_subnet_ids` | list(string) | yes | — | Private subnets for worker nodes |
| `node_instance_type` | string | no | `t3a.large` | EC2 instance type |
| `node_desired` | number | no | `2` | Desired node count |
| `node_min` | number | no | `2` | Minimum node count |
| `node_max` | number | no | `2` | Maximum node count |
| `node_disk_size` | number | no | `20` | Disk size in GB |
| `node_ami_type` | string | no | `AL2_x86_64` | AMI type |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | API server endpoint |
| `cluster_ca_certificate` | Base64-encoded CA certificate |
| `cluster_token` | Auth token (sensitive) |
| `cluster_security_group_id` | Control plane security group ID |
| `oidc_provider_arn` | OIDC provider ARN (for IRSA) |
| `oidc_provider_url` | OIDC provider URL without `https://` |
| `node_role_arn` | Worker node IAM role ARN |

## Notes

- Both public and private endpoint access are enabled by default.
- The OIDC provider is required for all IRSA-based add-ons.
