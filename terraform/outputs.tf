output "helpdesk_url" {
  description = "Helpdesk URL (reachable once the ALB is up and DNS has propagated)"
  value       = "https://${var.helpdesk_dns}"
}

output "helpdesk_xterm_url" {
  description = "Helpdesk xterm URL"
  value       = "https://${local.helpdesk_xterm_dns}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = module.vpc.nat_gateway_ip
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "s3_bucket_name" {
  description = "ai-studio S3 bucket name"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ai-studio S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = module.eks_addons.alb_controller_role_arn
}

output "efs_csi_role_arn" {
  description = "IAM role ARN for the EFS CSI Driver"
  value       = module.eks_addons.efs_csi_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = module.eks_addons.external_dns_role_arn
}

output "helpdesk_analytics_collector_irsa_role_arn" {
  description = "IAM role ARN for helpdesk analytics collector IRSA"
  value       = module.eks_addons.helpdesk_analytics_collector_irsa_role_arn
}

output "s3_userdata_bucket_name" {
  description = "ai-studio-userdata S3 bucket name"
  value       = module.s3.userdata_bucket_name
}

output "efs_id" {
  description = "EFS filesystem ID"
  value       = module.efs.efs_id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.acm.certificate_arn
}

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = module.eks.alb_sg_id
}

output "helm_ai_studio_status" {
  description = "Helm release status for ai-studio"
  value       = module.helm_ai_studio.release_status
}

output "database_backend" {
  description = "MongoDB backend in use (mongodb or documentdb)"
  value       = var.database_backend
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint (null when database_backend = mongodb)"
  value       = local.documentdb_enabled ? module.documentdb[0].cluster_endpoint : null
}

output "documentdb_master_secret_arn" {
  description = "Secrets Manager ARN holding the DocumentDB master credentials (null when database_backend = mongodb)"
  value       = local.documentdb_enabled ? module.documentdb[0].master_secret_arn : null
}

output "documentdb_security_group_id" {
  description = "DocumentDB security group ID (null when database_backend = mongodb)"
  value       = local.documentdb_enabled ? module.documentdb[0].security_group_id : null
}

output "alerts_sns_topic_arn" {
  description = "SNS topic for SOC2 alarm notifications — add subscriptions (email, chat, paging) to it"
  value       = module.monitoring.sns_topic_arn
}

output "monitoring_alarm_names" {
  description = "CloudWatch alarms created for SOC2 monitoring"
  value       = module.monitoring.alarm_names
}
