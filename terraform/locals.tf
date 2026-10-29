data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  # Auto-select VPC CIDR if not provided
  vpc_cidr = var.vpc_cidr != null ? var.vpc_cidr : "10.0.0.0/16"

  # Derived resource names from prefix
  # All resources follow the pattern: <prefix>-<resource-type>
  resource_prefix  = var.prefix
  vpc_name         = "${var.prefix}-vpc"
  eks_cluster_name = "${var.prefix}-eks"
  efs_name         = "${var.prefix}-efs"

  # Kubernetes namespace for the Helpdesk release. Always "duplo-ai" (independent of prefix). Passed to
  # both helm-ai-studio and eks-addons so the IRSA trust policies match where the pods actually run.
  helpdesk_namespace = "duplo-ai"

  # DocumentDB resources
  documentdb_enabled     = var.database_backend == "documentdb"
  documentdb_name_prefix = var.prefix # Already validated to be lowercase and compliant

  # Values derived from helpdesk_dns when not set, so a minimal tfvars only needs the primary hostname.
  # e.g. helpdesk.example.com -> zone example.com, xterm helpdesk-xterm.example.com
  helpdesk_dns_labels = split(".", var.helpdesk_dns)
  route53_zone_name   = var.route53_zone_name != null ? var.route53_zone_name : join(".", slice(local.helpdesk_dns_labels, 1, length(local.helpdesk_dns_labels)))
  helpdesk_xterm_dns  = var.helpdesk_xterm_dns != null ? var.helpdesk_xterm_dns : "${local.helpdesk_dns_labels[0]}-xterm.${join(".", slice(local.helpdesk_dns_labels, 1, length(local.helpdesk_dns_labels)))}"

  # null = only the helpdesk zone; "" keeps the old manage-every-zone behaviour.
  external_dns_domain_filter = var.external_dns_domain_filter != null ? var.external_dns_domain_filter : local.route53_zone_name

  helpdesk_analytics_collector_app_instance = var.helpdesk_analytics_collector_app_instance != null ? var.helpdesk_analytics_collector_app_instance : "${var.prefix}-${local.account_id}-${var.aws_region}"

  # Generated secrets are used only when the variable is left empty.
  jwt_shared_secret     = var.jwt_shared_secret != "" ? var.jwt_shared_secret : random_password.jwt_shared_secret[0].result
  mongodb_root_password = var.mongodb_root_password != "" ? var.mongodb_root_password : try(random_password.mongodb_root_password[0].result, "")
}

# Alphanumeric only: both values are rendered into Helm values, and the Mongo password into connection URIs.
resource "random_password" "jwt_shared_secret" {
  count   = var.jwt_shared_secret == "" ? 1 : 0
  length  = 64
  special = false
}

resource "random_password" "mongodb_root_password" {
  count   = var.mongodb_root_password == "" && !local.documentdb_enabled ? 1 : 0
  length  = 32
  special = false
}
