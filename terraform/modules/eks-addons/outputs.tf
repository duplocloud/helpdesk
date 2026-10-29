output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb.arn
}

output "efs_csi_role_arn" {
  description = "IAM role ARN for the EFS CSI Driver"
  value       = aws_iam_role.efs.arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "backend_s3_role_arn" {
  description = "IAM role ARN for backend S3 access (IRSA)"
  value       = aws_iam_role.backend_s3.arn
}

output "bedrock_subscription_role_arn" {
  description = "IAM role ARN for Bedrock subscription job (IRSA)"
  value       = aws_iam_role.bedrock_subscription.arn
}

output "helpdesk_backend_irsa_role_arn" {
  description = "IAM role ARN for helpdesk backend (sts:AssumeRole on DuploCloud-* roles)"
  value       = aws_iam_role.helpdesk_backend.arn
}

output "helpdesk_agent_irsa_role_arn" {
  description = "IAM role ARN for helpdesk duplo-agent (Bedrock inference)"
  value       = aws_iam_role.helpdesk_agent_bedrock.arn
}

output "helpdesk_analytics_collector_irsa_role_arn" {
  description = "IAM role ARN for helpdesk analytics collector"
  value       = aws_iam_role.helpdesk_analytics_collector.arn
}

output "helpdesk_analytics_collector_sa_name" {
  description = "Kubernetes service account name for helpdesk analytics collector"
  value       = var.helpdesk_analytics_collector_sa_name
}
