module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.resource_prefix
  vpc_cidr           = local.vpc_cidr
  azs                = local.azs
  log_retention_days = var.log_retention_days
}

module "eks" {
  source = "./modules/eks"

  name_prefix        = local.resource_prefix
  cluster_name       = local.eks_cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = var.node_min
  node_max           = var.node_max
  node_disk_size     = var.node_disk_size
  node_ami_type      = var.node_ami_type
  log_retention_days = var.log_retention_days
}

module "eks_addons" {
  source = "./modules/eks-addons"

  name_prefix                = local.resource_prefix
  cluster_name               = local.eks_cluster_name
  oidc_provider_arn          = module.eks.oidc_provider_arn
  oidc_provider_url          = module.eks.oidc_provider_url
  vpc_id                     = module.vpc.vpc_id
  external_dns_domain_filter = local.external_dns_domain_filter
  s3_bucket_arn              = module.s3.bucket_arn
  s3_userdata_bucket_arn     = module.s3.userdata_bucket_arn
  node_role_name             = module.eks.node_role_name
  helpdesk_namespace         = local.helpdesk_namespace

  depends_on = [module.eks]
}

module "s3" {
  source = "./modules/s3"

  account_id                = local.account_id
  bucket_name_suffix        = var.s3_bucket_name_suffix
  lifecycle_enabled         = var.s3_lifecycle_enabled
  lifecycle_expiration_days = var.s3_lifecycle_expiration_days

  noncurrent_version_expiration_days = var.s3_noncurrent_version_expiration_days
}

module "efs" {
  source = "./modules/efs"

  name_prefix        = local.resource_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_sg_id         = module.eks.node_sg_id
  eks_cluster_sg_id  = module.eks.eks_cluster_sg_id

  depends_on = [module.eks]
}

module "documentdb" {
  source = "./modules/documentdb"
  count  = local.documentdb_enabled ? 1 : 0

  name_prefix               = local.documentdb_name_prefix
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  source_security_group_ids = [module.eks.node_sg_id, module.eks.eks_cluster_sg_id]

  instance_class          = var.documentdb_instance_class
  instance_count          = var.documentdb_instance_count
  engine_version          = var.documentdb_engine_version
  backup_retention_period = var.documentdb_backup_retention_period
  deletion_protection     = var.documentdb_deletion_protection
  skip_final_snapshot     = var.documentdb_skip_final_snapshot
}

module "eks_storage" {
  source = "./modules/eks-storage"

  efs_id = module.efs.efs_id

  depends_on = [module.eks_addons, module.efs]
}

module "acm" {
  source = "./modules/acm"

  helpdesk_dns       = var.helpdesk_dns
  helpdesk_xterm_dns = local.helpdesk_xterm_dns
  route53_zone_name  = local.route53_zone_name
}

module "helm_ai_studio" {
  source                                     = "./modules/helm-ai-studio"
  namespace                                  = local.helpdesk_namespace
  chart_version                              = var.helm_ai_studio_chart_version
  storage_class_name                         = module.eks_storage.storage_class_name
  helpdesk_dns                               = var.helpdesk_dns
  helpdesk_xterm_dns                         = local.helpdesk_xterm_dns
  certificate_arn                            = module.acm.certificate_arn
  alb_sg_ids                                 = module.eks.alb_sg_id
  public_subnet_ids                          = join(",", module.vpc.public_subnet_ids)
  jwt_shared_secret                          = local.jwt_shared_secret
  google_oauth_enabled                       = var.google_oauth_enabled
  google_client_id                           = var.google_client_id
  google_client_secret                       = var.google_client_secret
  microsoft_oauth_enabled                    = var.microsoft_oauth_enabled
  microsoft_client_id                        = var.microsoft_client_id
  microsoft_client_secret                    = var.microsoft_client_secret
  microsoft_tenant_id                        = var.microsoft_tenant_id
  mongodb_enabled                            = !local.documentdb_enabled
  mongodb_root_password                      = local.mongodb_root_password
  mongodb_connection_string                  = local.documentdb_enabled ? module.documentdb[0].connection_string : ""
  auth_super_users                           = var.auth_super_users
  slack_backend_enabled                      = var.slack_backend_enabled
  slack_backend_image_tag                    = var.slack_backend_image_tag
  slack_helpdesk_default_agent               = var.slack_helpdesk_default_agent
  slack_helpdesk_default_workspace           = var.slack_helpdesk_default_workspace
  slack_app_portals                          = var.slack_app_portals
  slack_app_token                            = var.slack_app_token
  slack_bot_token                            = var.slack_bot_token
  bedrock_subscription_enabled               = true
  bedrock_service_account_name               = "duplo-ai-helpdesk-bedrock-subscription"
  bedrock_irsa_role_arn                      = module.eks_addons.bedrock_subscription_role_arn
  helpdesk_backend_irsa_role_arn             = module.eks_addons.helpdesk_backend_irsa_role_arn
  helpdesk_agent_irsa_role_arn               = module.eks_addons.helpdesk_agent_irsa_role_arn
  helpdesk_analytics_collector_irsa_role_arn = module.eks_addons.helpdesk_analytics_collector_irsa_role_arn
  helpdesk_analytics_collector_app_instance  = local.helpdesk_analytics_collector_app_instance
  helpdesk_analytics_collector_enabled       = var.helpdesk_analytics_collector_enabled
  values_output_path                         = "${path.root}/values.yml"

  depends_on = [module.eks_addons, module.eks_storage, module.acm]
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix         = local.resource_prefix
  aws_region          = var.aws_region
  aws_profile         = var.aws_profile
  cluster_name        = module.eks.cluster_name
  ingress_stack       = "${local.helpdesk_namespace}/${module.helm_ai_studio.release_name}"
  node_group_asg_name = module.eks.node_group_asg_name

  cpu_threshold_percent               = var.alarm_cpu_threshold_percent
  alb_response_time_threshold_seconds = var.alarm_alb_response_time_threshold_seconds
  alb_5xx_threshold_count             = var.alarm_alb_5xx_threshold_count

  # No module-level depends_on on helm_ai_studio: it would defer the ALB lookup to apply time whenever
  # anything in that module changes (e.g. the mongodump primer Job, recreated on every apply), making the
  # ALB alarms show a spurious update. Ordering already comes from ingress_stack referencing the release.
}
