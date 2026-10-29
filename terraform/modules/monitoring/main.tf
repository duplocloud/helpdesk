# SOC2 monitoring: an SNS topic for alarm notifications (subscriptions are added by the operator, e.g. an
# email address or a paging integration), a CPU alarm on the worker-node Auto Scaling Group, and ALB alarms.

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-helpdesk-alerts"

  tags = { Name = "${var.name_prefix}-helpdesk-alerts" }
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ── EC2 CPU (per Auto Scaling Group, not per instance) ────────────────────────
# Nodes are replaced on scaling, AMI rolls and node-group updates, so per-instance alarms would go stale.
# EC2 publishes CPUUtilization aggregated by AutoScalingGroupName, which follows the group's membership.
resource "aws_cloudwatch_metric_alarm" "node_cpu" {
  alarm_name          = "${var.name_prefix}-eks-nodes-cpu-high"
  alarm_description   = "Average CPU of the Helpdesk EKS worker nodes (ASG ${var.node_group_asg_name}) is above ${var.cpu_threshold_percent}%."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = var.node_group_asg_name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.cpu_threshold_percent
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ── ALB discovery ─────────────────────────────────────────────────────────────
# The ALB isn't a Terraform resource: the AWS Load Balancer Controller creates it from the chart's Ingress,
# asynchronously, after the Helm release is submitted. Wait for it once (first apply), then look it up by
# the tags the controller always sets. The lookup uses the plural data source, which returns an empty list
# rather than erroring, so a later plan/destroy still works if the ALB is already gone.
resource "terraform_data" "wait_for_alb" {
  triggers_replace = [var.cluster_name, var.ingress_stack]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      for i in $(seq 1 60); do
        arn="$(aws ${local.aws_cli_flags} resourcegroupstaggingapi get-resources \
          --resource-type-filters elasticloadbalancing:loadbalancer \
          --tag-filters Key=elbv2.k8s.aws/cluster,Values='${var.cluster_name}' Key=ingress.k8s.aws/stack,Values='${var.ingress_stack}' \
          --query 'ResourceTagMappingList[0].ResourceARN' --output text 2>/dev/null || true)"
        if [ -n "$arn" ] && [ "$arn" != "None" ]; then
          aws ${local.aws_cli_flags} elbv2 wait load-balancer-available --load-balancer-arns "$arn"
          echo "ALB ready: $arn"; exit 0
        fi
        echo "Waiting for the ALB controller to create the load balancer ($i/60)..."; sleep 10
      done
      echo "Timed out after 10 minutes waiting for the Helpdesk ALB (tags: elbv2.k8s.aws/cluster=${var.cluster_name}, ingress.k8s.aws/stack=${var.ingress_stack})." >&2
      exit 1
    EOT
  }
}

locals {
  aws_cli_flags = join(" ", compact([
    "--region ${var.aws_region}",
    var.aws_profile != "" ? "--profile ${var.aws_profile}" : "",
  ]))
}

data "aws_lbs" "helpdesk" {
  tags = {
    "elbv2.k8s.aws/cluster" = var.cluster_name
    "ingress.k8s.aws/stack" = var.ingress_stack
  }

  depends_on = [terraform_data.wait_for_alb]
}

locals {
  # "app/<name>/<id>" — the LoadBalancer dimension value. one() errors on more than one match, on purpose:
  # alarming on an arbitrary one of several ALBs would be silently wrong.
  alb_arns       = tolist(data.aws_lbs.helpdesk.arns)
  alb_arn_suffix = length(local.alb_arns) == 0 ? "" : regex("loadbalancer/(.+)$", one(local.alb_arns))[0]
}

# ── ALB alarms ────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.name_prefix}-alb-target-response-time-high"
  alarm_description   = "Average Helpdesk ALB target response time is above ${var.alb_response_time_threshold_seconds}s."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = local.alb_arn_suffix }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = var.alb_response_time_threshold_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# 5xx from the ALB itself (502/503/504 — e.g. no healthy targets) plus 5xx returned by the app.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-5xx-errors-high"
  alarm_description   = "Helpdesk ALB 5xx responses (ELB + target) are at or above ${var.alb_5xx_threshold_count} per 5 minutes."
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold_count
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "total_5xx"
    expression  = "FILL(elb_5xx, 0) + FILL(target_5xx, 0)"
    label       = "ELB + target 5xx"
    return_data = true
  }

  metric_query {
    id = "elb_5xx"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
      stat        = "Sum"
      period      = 300
    }
  }

  metric_query {
    id = "target_5xx"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = local.alb_arn_suffix }
      stat        = "Sum"
      period      = 300
    }
  }
}

# UnHealthyHostCount is published per target group, and the controller creates one target group per
# Service with generated names that change when Services change. A Metrics Insights query covers every
# target group behind this ALB without tracking their names.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  alarm_description   = "At least one Helpdesk ALB target is unhealthy."
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "unhealthy"
    expression  = "SELECT MAX(UnHealthyHostCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer = '${local.alb_arn_suffix}'"
    period      = 60
    label       = "Max unhealthy targets in any target group"
    return_data = true
  }
}
