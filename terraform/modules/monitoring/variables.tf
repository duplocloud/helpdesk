variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region (used by the ALB wait step's AWS CLI calls)"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile for the ALB wait step's AWS CLI calls (empty = default credential chain)"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name (matches the ALB controller's elbv2.k8s.aws/cluster tag)"
  type        = string
}

variable "ingress_stack" {
  description = "\"<namespace>/<ingress name>\" of the Helpdesk Ingress (matches the ALB controller's ingress.k8s.aws/stack tag)"
  type        = string
}

variable "node_group_asg_name" {
  description = "Auto Scaling Group of the EKS managed node group"
  type        = string
}

variable "cpu_threshold_percent" {
  description = "Node CPU alarm threshold (average %, over 3 consecutive 5-minute periods)"
  type        = number
  default     = 80
}

variable "alb_response_time_threshold_seconds" {
  description = "ALB average target response time alarm threshold (seconds; 3 of 5 one-minute periods). Generous by default: LLM-backed requests are legitimately slow."
  type        = number
  default     = 10
}

variable "alb_5xx_threshold_count" {
  description = "ALB 5xx (ELB + target) alarm threshold, per 5 minutes"
  type        = number
  default     = 10
}
