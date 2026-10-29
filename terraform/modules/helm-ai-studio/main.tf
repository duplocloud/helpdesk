data "aws_region" "current" {}

locals {
  rendered_values = templatefile("${path.module}/templates/values.yml.tftpl", {
    storage_class_name                         = var.storage_class_name
    helpdesk_dns                               = var.helpdesk_dns
    helpdesk_xterm_dns                         = var.helpdesk_xterm_dns
    infra_region                               = data.aws_region.current.name
    certificate_arn                            = var.certificate_arn
    alb_sg_ids                                 = var.alb_sg_ids
    public_subnet_ids                          = var.public_subnet_ids
    jwt_shared_secret                          = var.jwt_shared_secret
    google_client_id                           = var.google_oauth_enabled ? var.google_client_id : ""
    google_client_secret                       = var.google_oauth_enabled ? var.google_client_secret : ""
    microsoft_client_id                        = var.microsoft_oauth_enabled ? var.microsoft_client_id : ""
    microsoft_client_secret                    = var.microsoft_oauth_enabled ? var.microsoft_client_secret : ""
    microsoft_tenant_id                        = var.microsoft_oauth_enabled ? var.microsoft_tenant_id : ""
    mongodb_enabled                            = var.mongodb_enabled
    mongodb_root_password                      = var.mongodb_root_password
    mongodb_connection_string                  = var.mongodb_connection_string
    auth_super_users                           = var.auth_super_users
    slack_backend_enabled                      = var.slack_backend_enabled
    slack_backend_image_tag                    = var.slack_backend_image_tag
    slack_helpdesk_default_agent               = var.slack_helpdesk_default_agent
    slack_helpdesk_default_workspace           = var.slack_helpdesk_default_workspace
    slack_app_portals                          = var.slack_app_portals
    slack_app_token                            = var.slack_app_token
    slack_bot_token                            = var.slack_bot_token
    bedrock_subscription_enabled               = var.bedrock_subscription_enabled
    bedrock_service_account_name               = var.bedrock_service_account_name
    helpdesk_analytics_collector_enabled       = var.helpdesk_analytics_collector_enabled
    helpdesk_analytics_collector_irsa_role_arn = var.helpdesk_analytics_collector_irsa_role_arn
    helpdesk_analytics_collector_app_instance  = var.helpdesk_analytics_collector_app_instance
    helpdesk_agent_irsa_role_arn               = var.helpdesk_agent_irsa_role_arn
    helpdesk_backend_irsa_role_arn             = var.helpdesk_backend_irsa_role_arn
  })
}

resource "local_file" "values" {
  content  = local.rendered_values
  filename = var.values_output_path
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1" "values_yaml" {
  metadata {
    name      = "${var.release_name}-values"
    namespace = var.namespace
  }

  data = {
    "values.yml" = local.rendered_values
  }

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_service_account_v1" "bedrock_subscription" {
  metadata {
    name      = var.bedrock_service_account_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"     = var.bedrock_irsa_role_arn
      "meta.helm.sh/release-name"      = var.release_name
      "meta.helm.sh/release-namespace" = var.namespace
    }
  }

  depends_on = [kubernetes_namespace.this]
}

resource "helm_release" "ai_studio" {
  name       = var.release_name
  repository = "oci://quay.io/duplocloud"
  chart      = "helpdesk"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 900

  # false: the chart's own "<release>-mongodb-mongodump" PersistentVolumeClaim uses a
  # WaitForFirstConsumer StorageClass, so it stays Pending until some pod mounts it — and nothing does
  # on a fresh install (the real backup CronJob only fires nightly). With the default wait=true, Helm's
  # install-wait fails every first install with "INSTALLATION FAILED: no PersistentVolumeClaim ... found"
  # before the pods it's waiting on even get a chance to schedule. kubernetes_job_v1.mongodump_pvc_primer
  # below forces that PVC to bind right after this release submits its manifests, working around that
  # chart-level race. Because wait is now false,
  # `terraform apply` reports success once the release's objects are submitted, not once every pod is
  # Ready — consistent with the README's existing guidance to verify with `kubectl get pods` afterward.
  wait          = false
  wait_for_jobs = false

  values = [local.rendered_values]

  depends_on = [
    local_file.values,
    kubernetes_namespace.this,
    kubernetes_config_map_v1.values_yaml,
    kubernetes_service_account_v1.bedrock_subscription
  ]
}

# Forces the chart's mongodump PVC out of Pending on a fresh install — see the comment on
# helm_release.ai_studio above. A Job whose pod just mounts the PVC is enough to trigger
# WaitForFirstConsumer binding; wait_for_completion blocks this resource (and therefore `terraform
# apply`) until that happens, so by the time apply finishes the PVC is bound and the chart's real pods can
# proceed normally. Safe to re-run: kubernetes_job_v1 replaces the Job on every apply, and a PVC that's
# already Bound stays Bound regardless of what mounts it next. Skipped with an external database: the chart
# only renders the mongodump PVC when mongodb.enabled=true, so the Job would wait on a PVC that never exists.
resource "kubernetes_job_v1" "mongodump_pvc_primer" {
  count = var.mongodb_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-mongodump-pvc-primer"
    namespace = var.namespace
  }

  spec {
    backoff_limit              = 0
    ttl_seconds_after_finished = 120

    template {
      metadata {}
      spec {
        restart_policy = "Never"

        container {
          name    = "primer"
          image   = "public.ecr.aws/docker/library/busybox:latest"
          command = ["/bin/true"]

          volume_mount {
            name       = "mongodump"
            mount_path = "/mnt/mongodump"
          }
        }

        volume {
          name = "mongodump"
          persistent_volume_claim {
            claim_name = "${var.release_name}-mongodb-mongodump"
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "3m"
  }

  depends_on = [helm_release.ai_studio]
}

moved {
  from = kubernetes_job_v1.mongodump_pvc_primer
  to   = kubernetes_job_v1.mongodump_pvc_primer[0]
}
