# Module: vpc

Creates a VPC with public and private subnets spread across availability zones, an Internet Gateway, a single NAT Gateway (cost-optimized), and route tables. Subnets are tagged for EKS integration.

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `cluster_name` | string | yes | EKS cluster name — used in resource names and subnet tags |
| `vpc_cidr` | string | yes | VPC CIDR block (e.g. `10.0.0.0/16`) |
| `azs` | list(string) | yes | Availability zones to deploy subnets into |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs |
| `nat_gateway_ip` | NAT Gateway Elastic IP |

## Notes

- Public subnets are tagged `kubernetes.io/role/elb = 1` for ALB provisioning.
- Private subnets are tagged `kubernetes.io/role/internal-elb = 1` for internal ALB provisioning.
- Subnet CIDRs are auto-calculated using `cidrsubnet()` with `/24` blocks.
