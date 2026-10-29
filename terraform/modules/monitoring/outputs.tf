output "sns_topic_arn" {
  description = "SNS topic the alarms notify — subscribe personnel (email, chat, paging) to it"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "CloudWatch alarms created for SOC2 monitoring"
  value = [
    aws_cloudwatch_metric_alarm.node_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.alb_target_response_time.alarm_name,
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.alarm_name,
  ]
}

output "alb_arn_suffix" {
  description = "LoadBalancer dimension the ALB alarms are scoped to"
  value       = local.alb_arn_suffix
}
