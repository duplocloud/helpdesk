variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "duplo-ai-helpdesk"
}

variable "namespace" {
  description = "Kubernetes namespace for the release (always 'duplo-ai')"
  type        = string
  default     = "duplo-ai"
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.2.24"
}

variable "storage_class_name" {
  description = "Kubernetes StorageClass name for EFS (used by backend and duploAgent)"
  type        = string
  default     = "ai-studio-efs"
}

variable "helpdesk_dns" {
  description = "Helpdesk DNS hostname (e.g. helpdesk.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "Helpdesk xterm DNS hostname"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for ALB"
  type        = string
}

variable "alb_sg_ids" {
  description = "Comma-separated ALB security group IDs"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB (comma-separated string)"
  type        = string
}

variable "jwt_shared_secret" {
  description = "JWT shared secret"
  type        = string
  sensitive   = true
}

variable "google_oauth_enabled" {
  description = "Enable Google OAuth login. When false, Google credentials are not rendered into the Helm values."
  type        = bool
  default     = true
}

variable "google_client_id" {
  description = "Google OAuth client ID. Used only when google_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth client secret. Used only when google_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "microsoft_oauth_enabled" {
  description = "Enable Microsoft (Entra) OAuth login. When false, Microsoft credentials are not rendered into the Helm values."
  type        = bool
  default     = false
}

variable "microsoft_client_id" {
  description = "Microsoft (Entra) OAuth client ID. Used only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "microsoft_client_secret" {
  description = "Microsoft (Entra) OAuth client secret. Used only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "microsoft_tenant_id" {
  description = "Microsoft (Entra) tenant ID (e.g. \"common\" or a tenant GUID). Used only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
}

variable "mongodb_enabled" {
  description = "Deploy the chart's bundled MongoDB. When false, the chart uses mongodb_connection_string (e.g. DocumentDB) instead."
  type        = bool
  default     = true
}

variable "mongodb_root_password" {
  description = "MongoDB root password. Used only when mongodb_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mongodb_connection_string" {
  description = "External MongoDB/DocumentDB connection string. Used only when mongodb_enabled = false."
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth_super_users" {
  description = "Comma-separated list of super user emails"
  type        = string
  default     = ""
}

variable "values_output_path" {
  description = "Local path to write the rendered values.yml"
  type        = string
  default     = "./values.yml"
}

variable "bedrock_subscription_enabled" {
  description = "Enable Bedrock subscription hook job"
  type        = bool
  default     = true
}

variable "bedrock_service_account_name" {
  description = "Service account name used by the Bedrock subscription job"
  type        = string
  default     = "duplo-ai-helpdesk-bedrock-subscription"
}

variable "bedrock_irsa_role_arn" {
  description = "IAM role ARN to annotate on the Bedrock subscription service account for IRSA"
  type        = string
}

variable "helpdesk_backend_irsa_role_arn" {
  description = "IAM role ARN to annotate on the helpdesk backend service account for IRSA (sts:AssumeRole on DuploCloud-*)"
  type        = string
}

variable "helpdesk_agent_irsa_role_arn" {
  description = "IAM role ARN to annotate on the helpdesk duplo-agent service account for IRSA (Bedrock inference)"
  type        = string
}

variable "helpdesk_analytics_collector_irsa_role_arn" {
  description = "IAM role ARN to annotate on the helpdesk analytics collector service account for IRSA trust anchoring"
  type        = string
}

variable "helpdesk_analytics_collector_enabled" {
  description = "Enable the analytics collector deployment in rendered Helm values"
  type        = bool
}

variable "helpdesk_analytics_collector_app_instance" {
  description = "Required app-instance value injected into collector.product.instance"
  type        = string
}

# ── Slack Backend ─────────────────────────────────────────────────────────────

variable "slack_backend_enabled" {
  description = "Enable Slack backend"
  type        = bool
  default     = false
}

variable "slack_backend_image_tag" {
  description = "Slack backend container image tag"
  type        = string
  default     = ""
}

variable "slack_helpdesk_default_agent" {
  description = "Default agent for Slack helpdesk"
  type        = string
  default     = ""
}

variable "slack_helpdesk_default_workspace" {
  description = "Default workspace for Slack helpdesk"
  type        = string
  default     = ""
}

variable "slack_app_portals" {
  description = "Slack app portals JSON config"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_app_token" {
  description = "Slack app token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack bot token"
  type        = string
  default     = ""
  sensitive   = true
}
