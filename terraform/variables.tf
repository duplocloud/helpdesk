variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile name to use for provider and EKS token exec auth"
  type        = string
  default     = ""
}

variable "prefix" {
  description = "Prefix for all resource names (e.g., 'duplo-ai', 'acme'). Used to create semantic names like <prefix>-vpc, <prefix>-eks, <prefix>-efs, etc."
  type        = string
  default     = "duplo-ai"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.prefix))
    error_message = "prefix must start with a lowercase letter, contain only lowercase letters, digits, and hyphens, and be 1-20 characters long."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster (defaults to latest stable)"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Auto-selected if null."
  type        = string
  default     = null
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3a.large"
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "node_ami_type" {
  description = "AMI type for worker nodes (e.g. AL2023_x86_64_STANDARD)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "external_dns_domain_filter" {
  description = "Domain filter for External DNS (e.g. example.com). null (default) = the Route53 hosted zone of helpdesk_dns; \"\" = manage every hosted zone in the account."
  type        = string
  default     = null
}

variable "s3_bucket_name_suffix" {
  description = "Optional suffix for the S3 bucket names (ai-studio-<account_id>-<suffix>). Leave empty to keep the default names; set it to run more than one deployment in the same AWS account."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^([a-z0-9][a-z0-9-]{0,29}[a-z0-9])?$", var.s3_bucket_name_suffix))
    error_message = "s3_bucket_name_suffix must be empty, or 2-31 lowercase letters, digits and hyphens, not starting or ending with a hyphen."
  }
}

variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle rules on the ai-studio bucket"
  type        = bool
  default     = false
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days after which objects expire (requires s3_lifecycle_enabled = true)"
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ── Helm Chart ────────────────────────────────────────────────────────────────
variable "helm_ai_studio_chart_version" {
  description = "Helm chart version for duplo-ai-helpdesk"
  type        = string
  default     = "0.2.24"
}

variable "jwt_shared_secret" {
  description = "JWT shared secret. Leave empty to generate a random one (kept in Terraform state)."
  type        = string
  default     = ""
  sensitive   = true
}

# ── Google OAuth (optional) ─────────────────────────────────────────────────
variable "google_oauth_enabled" {
  description = "Enable Google OAuth login. When true, google_client_id and google_client_secret are required."
  type        = bool
  default     = true

  validation {
    condition     = !var.google_oauth_enabled || (var.google_client_id != "" && var.google_client_secret != "")
    error_message = "google_client_id and google_client_secret must be non-empty when google_oauth_enabled = true."
  }
}

variable "google_client_id" {
  description = "Google OAuth client ID. Required only when google_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth client secret. Required only when google_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

# ── Microsoft (Entra) OAuth (optional) ──────────────────────────────────────
variable "microsoft_oauth_enabled" {
  description = "Enable Microsoft (Entra) OAuth login. When true, microsoft_client_id, microsoft_client_secret and microsoft_tenant_id are required."
  type        = bool
  default     = false

  validation {
    condition     = !var.microsoft_oauth_enabled || (var.microsoft_client_id != "" && var.microsoft_client_secret != "" && var.microsoft_tenant_id != "")
    error_message = "microsoft_client_id, microsoft_client_secret and microsoft_tenant_id must be non-empty when microsoft_oauth_enabled = true."
  }
}

variable "microsoft_client_id" {
  description = "Microsoft (Entra) OAuth client ID. Required only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "microsoft_client_secret" {
  description = "Microsoft (Entra) OAuth client secret. Required only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
  sensitive   = true
}

variable "microsoft_tenant_id" {
  description = "Microsoft (Entra) tenant ID (e.g. \"common\" or a tenant GUID). Required only when microsoft_oauth_enabled = true."
  type        = string
  default     = ""
}

# ── Database backend ────────────────────────────────────────────────────────
variable "database_backend" {
  description = "MongoDB backend: \"mongodb\" (chart's bundled in-cluster MongoDB StatefulSet) or \"documentdb\" (managed AWS DocumentDB cluster provisioned by this stack)"
  type        = string
  default     = "mongodb"

  validation {
    condition     = contains(["mongodb", "documentdb"], var.database_backend)
    error_message = "database_backend must be \"mongodb\" or \"documentdb\"."
  }
}

variable "mongodb_root_password" {
  description = "MongoDB root password (database_backend = \"mongodb\" only). Leave empty to generate a random one (kept in Terraform state)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "documentdb_instance_class" {
  description = "DocumentDB instance class (database_backend = \"documentdb\" only)"
  type        = string
  default     = "db.t3.medium"
}

variable "documentdb_instance_count" {
  description = "Number of DocumentDB instances; 2+ adds failover replicas in other AZs (database_backend = \"documentdb\" only)"
  type        = number
  default     = 1

  validation {
    condition     = var.documentdb_instance_count >= 1 && var.documentdb_instance_count <= 16
    error_message = "documentdb_instance_count must be between 1 and 16."
  }
}

variable "documentdb_engine_version" {
  description = "Pinned DocumentDB engine version (database_backend = \"documentdb\" only)"
  type        = string
  default     = "5.0.0"
}

variable "documentdb_backup_retention_period" {
  description = "Days to retain DocumentDB automated backups, 1-35 (database_backend = \"documentdb\" only)"
  type        = number
  default     = 7

  validation {
    condition     = var.documentdb_backup_retention_period >= 1 && var.documentdb_backup_retention_period <= 35
    error_message = "documentdb_backup_retention_period must be between 1 and 35."
  }
}

variable "documentdb_deletion_protection" {
  description = "Enable DocumentDB deletion protection — recommended for production (database_backend = \"documentdb\" only)"
  type        = bool
  default     = false
}

variable "documentdb_skip_final_snapshot" {
  description = "Skip the final DocumentDB snapshot on destroy (database_backend = \"documentdb\" only)"
  type        = bool
  default     = false
}

variable "auth_super_users" {
  description = "Comma-separated list of super user emails"
  type        = string
  default     = ""
}

variable "helpdesk_dns" {
  description = "Primary DNS name for the helpdesk (e.g. helpdesk.example.com). Its public Route53 hosted zone must already exist in this AWS account."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.helpdesk_dns))
    error_message = "helpdesk_dns must be a lowercase fully qualified hostname such as helpdesk.example.com (no scheme, no trailing dot)."
  }
}

variable "helpdesk_xterm_dns" {
  description = "DNS name for the helpdesk xterm service. null (default) = <first label of helpdesk_dns>-xterm.<rest>, e.g. helpdesk-xterm.example.com."
  type        = string
  default     = null
}

variable "route53_zone_name" {
  description = "Public Route53 hosted zone that holds helpdesk_dns (e.g. example.com). null (default) = helpdesk_dns without its first label."
  type        = string
  default     = null
}

variable "helpdesk_analytics_collector_app_instance" {
  description = "Analytics app instance identifier; must be unique per Helpdesk deployment in one cloud environment. null (default) = <prefix>-<account_id>-<aws_region>."
  type        = string
  default     = null
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

variable "helpdesk_analytics_collector_enabled" {
  description = "Enable the analytics collector in the rendered Helm values"
  type        = bool
  default     = true
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

# ── SOC2: logging & monitoring ──────────────────────────────────────────────
variable "log_retention_days" {
  description = "CloudWatch retention (days) for VPC flow logs and EKS control plane logs"
  type        = number
  default     = 365
}

variable "s3_noncurrent_version_expiration_days" {
  description = "Days to keep noncurrent (overwritten/deleted) object versions in the versioned ai-studio buckets"
  type        = number
  default     = 90
}

variable "alarm_cpu_threshold_percent" {
  description = "Worker-node ASG average CPU alarm threshold (%)"
  type        = number
  default     = 80
}

variable "alarm_alb_response_time_threshold_seconds" {
  description = "ALB average target response time alarm threshold (seconds)"
  type        = number
  default     = 10
}

variable "alarm_alb_5xx_threshold_count" {
  description = "ALB 5xx (ELB + target) alarm threshold per 5 minutes"
  type        = number
  default     = 10
}
