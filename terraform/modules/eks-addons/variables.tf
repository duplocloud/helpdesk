variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'duplo-ai', 'acme')"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (e.g., 'duplo-ai-eks')"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "external_dns_domain_filter" {
  description = "Domain filter for External DNS. Leave empty to manage all zones."
  type        = string
  default     = ""
}

variable "alb_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller"
  type        = string
  default     = "1.7.1"
}

variable "efs_csi_chart_version" {
  description = "Helm chart version for aws-efs-csi-driver"
  type        = string
  default     = "2.5.6"
}

variable "external_dns_chart_version" {
  description = "Helm chart version for external-dns"
  type        = string
  default     = "1.14.3"
}

variable "s3_bucket_arn" {
  description = "ARN of the main ai-studio S3 bucket"
  type        = string
}

variable "s3_userdata_bucket_arn" {
  description = "ARN of the ai-studio-userdata S3 bucket"
  type        = string
}

variable "backend_sa_namespace" {
  description = "Kubernetes namespace of the backend service account"
  type        = string
  default     = "default"
}

variable "backend_sa_name" {
  description = "Kubernetes service account name for the backend pod"
  type        = string
  default     = "ai-studio-backend"
}

variable "node_role_name" {
  description = "IAM role name for EKS worker nodes (to attach S3 policy)"
  type        = string
}

variable "helpdesk_namespace" {
  description = "Kubernetes namespace the Helpdesk chart is deployed into. Every Helpdesk IRSA trust policy is scoped to service accounts in this namespace, so it must match helm-ai-studio's namespace."
  type        = string
}

variable "bedrock_subscription_sa_name" {
  description = "Kubernetes service account name used by Bedrock subscription job"
  type        = string
  default     = "duplo-ai-helpdesk-bedrock-subscription"
}

variable "helpdesk_backend_sa_name" {
  description = "Kubernetes service account name for the helpdesk backend pod"
  type        = string
  default     = "duplo-ai-helpdesk-backend"
}

variable "helpdesk_agent_sa_name" {
  description = "Kubernetes service account name for the helpdesk duplo-agent pod"
  type        = string
  default     = "duplo-ai-helpdesk-duplo-agent"
}

variable "helpdesk_analytics_collector_sa_name" {
  description = "Kubernetes service account name for the helpdesk analytics collector pod"
  type        = string
  default     = "duplo-ai-helpdesk-collector"
}
