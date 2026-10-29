output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_token" {
  description = "Authentication token for the cluster"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "EKS cluster control plane security group ID"
  value       = aws_security_group.cluster.id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_role_arn" {
  description = "IAM role ARN for worker nodes"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "IAM role name for worker nodes"
  value       = aws_iam_role.node.name
}

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "node_sg_id" {
  description = "Worker node security group ID"
  value       = aws_security_group.nodes.id
}

output "eks_cluster_sg_id" {
  description = "EKS-managed cluster security group ID (attached to all nodes)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_asg_name" {
  description = "Auto Scaling Group backing the EKS managed node group"
  value       = aws_eks_node_group.default.resources[0].autoscaling_groups[0].name
}
