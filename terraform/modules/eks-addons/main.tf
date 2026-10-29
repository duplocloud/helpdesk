data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # IRSA trust policies for each add-on service account
  irsa_alb_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = "kube-system"
    service_account   = "aws-load-balancer-controller"
  })

  irsa_efs_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = "kube-system"
    service_account   = "efs-csi-controller-sa"
  })

  irsa_extdns_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = "kube-system"
    service_account   = "external-dns"
  })

  irsa_ebs_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = "kube-system"
    service_account   = "ebs-csi-controller-sa"
  })

  irsa_backend_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.backend_sa_namespace
    service_account   = var.backend_sa_name
  })

  irsa_bedrock_subscription_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_namespace
    service_account   = var.bedrock_subscription_sa_name
  })

  irsa_helpdesk_backend_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_namespace
    service_account   = var.helpdesk_backend_sa_name
  })

  irsa_helpdesk_agent_trust = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_namespace
    service_account   = var.helpdesk_agent_sa_name
  })

  irsa_helpdesk_analytics_collector = templatefile("${path.module}/templates/irsa-trust.json.tpl", {
    oidc_provider_arn = var.oidc_provider_arn
    oidc_provider_url = var.oidc_provider_url
    namespace         = var.helpdesk_namespace
    service_account   = var.helpdesk_analytics_collector_sa_name
  })
}

# ── AWS Load Balancer Controller ───────────────────────────────────────────────
resource "aws_iam_policy" "alb" {
  name   = "${var.name_prefix}-eks-alb-controller-policy"
  policy = file("${path.module}/templates/alb-iam-policy.json")
}

resource "aws_iam_role" "alb" {
  name               = "${var.name_prefix}-eks-alb-controller-role"
  assume_role_policy = local.irsa_alb_trust
}

resource "aws_iam_role_policy_attachment" "alb" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"
  timeout    = 600

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb.arn
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [aws_iam_role_policy_attachment.alb]
}

# ── EFS CSI Driver ────────────────────────────────────────────────────────────
resource "aws_iam_role" "efs" {
  name               = "${var.name_prefix}-eks-efs-csi-role"
  assume_role_policy = local.irsa_efs_trust
}

resource "aws_iam_role_policy_attachment" "efs" {
  role       = aws_iam_role.efs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "helm_release" "efs_csi" {
  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = var.efs_csi_chart_version
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.efs.arn
  }

  depends_on = [aws_iam_role_policy_attachment.efs]
}

# ── External DNS ──────────────────────────────────────────────────────────────
resource "aws_iam_policy" "external_dns" {
  name = "${var.name_prefix}-eks-external-dns-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.name_prefix}-eks-external-dns-role"
  assume_role_policy = local.irsa_extdns_trust
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  dynamic "set" {
    for_each = var.external_dns_domain_filter != "" ? [var.external_dns_domain_filter] : []
    content {
      name  = "domainFilters[0]"
      value = set.value
    }
  }

  depends_on = [aws_iam_role_policy_attachment.external_dns]
}

# ── EBS CSI Driver (managed addon) ────────────────────────────────────────────
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-eks-ebs-csi-role"
  assume_role_policy = local.irsa_ebs_trust
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

# ── Backend S3 IRSA ───────────────────────────────────────────────────────────
resource "aws_iam_policy" "backend_s3" {
  name = "${var.name_prefix}-backend-s3-policy"
  policy = templatefile("${path.module}/templates/backend-s3-policy.json.tpl", {
    s3_bucket_arn          = var.s3_bucket_arn
    s3_userdata_bucket_arn = var.s3_userdata_bucket_arn
    account_id             = local.account_id
    cluster_name           = var.cluster_name
  })
}

resource "aws_iam_role" "backend_s3" {
  name               = "${var.name_prefix}-backend-s3-role"
  assume_role_policy = local.irsa_backend_trust
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  role       = aws_iam_role.backend_s3.name
  policy_arn = aws_iam_policy.backend_s3.arn
}

# ── Bedrock Subscription IRSA ────────────────────────────────────────────────
resource "aws_iam_policy" "bedrock_subscription" {
  name = "${var.name_prefix}-bedrock-subscription-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MarketplaceSubscription"
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe"
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockSubscription"
        Effect = "Allow"
        Action = [
          "bedrock:CreateFoundationModelAgreement",
          "bedrock:ListFoundationModelAgreementOffers"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "bedrock_subscription" {
  name               = "${var.name_prefix}-bedrock-subscription-role"
  assume_role_policy = local.irsa_bedrock_subscription_trust
}

resource "aws_iam_role_policy_attachment" "bedrock_subscription" {
  role       = aws_iam_role.bedrock_subscription.name
  policy_arn = aws_iam_policy.bedrock_subscription.arn
}

# ── Helpdesk Backend IRSA (sts:AssumeRole on DuploCloud-* roles) ──────────────
resource "aws_iam_policy" "helpdesk_backend" {
  name = "${var.name_prefix}-helpdesk-backend-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeRoleDuploCloud"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${local.account_id}:role/DuploCloud-*"
      }
    ]
  })
}

resource "aws_iam_role" "helpdesk_backend" {
  name               = "${var.name_prefix}-helpdesk-backend-role"
  assume_role_policy = local.irsa_helpdesk_backend_trust
}

resource "aws_iam_role_policy_attachment" "helpdesk_backend" {
  role       = aws_iam_role.helpdesk_backend.name
  policy_arn = aws_iam_policy.helpdesk_backend.arn
}

# ── Helpdesk Agent IRSA (Bedrock inference) ───────────────────────────────────
resource "aws_iam_policy" "helpdesk_agent_bedrock" {
  name = "${var.name_prefix}-helpdesk-agent-bedrock-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInference"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:GetFoundationModelAvailability",
          "bedrock:GetFoundationModel",
          "bedrock:ListInferenceProfiles",
          "bedrock:GetInferenceProfile",
          "bedrock:CreateInferenceProfile",
          "bedrock:Rerank",
          "bedrock:ApplyGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:ListGuardrails"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "helpdesk_agent_bedrock" {
  name               = "${var.name_prefix}-helpdesk-agent-bedrock-role"
  assume_role_policy = local.irsa_helpdesk_agent_trust
}

resource "aws_iam_role_policy_attachment" "helpdesk_agent_bedrock" {
  role       = aws_iam_role.helpdesk_agent_bedrock.name
  policy_arn = aws_iam_policy.helpdesk_agent_bedrock.arn
}

resource "aws_iam_role" "helpdesk_analytics_collector" {
  name               = "${var.name_prefix}-helpdesk-analytics-collector-role"
  assume_role_policy = local.irsa_helpdesk_analytics_collector
}

# ── Node Role Permissions (S3 + Bedrock + AssumeRole for all pods) ────────────
resource "aws_iam_policy" "node_permissions" {
  name = "${var.name_prefix}-node-permissions-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*",
          var.s3_userdata_bucket_arn,
          "${var.s3_userdata_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ListFoundationModelAgreementOffers",
          "bedrock:CreateFoundationModelAgreement",
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
          "bedrock:ListCustomModels",
          "bedrock:GetCustomModel",
          "bedrock:CreateModelInvocationJob",
          "bedrock:GetModelInvocationJob",
          "bedrock:ListModelInvocationJobs",
          "bedrock:StopModelInvocationJob"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeAccessPoints"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_permissions" {
  role       = var.node_role_name
  policy_arn = aws_iam_policy.node_permissions.arn
}
