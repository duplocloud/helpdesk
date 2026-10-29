variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'duplo-ai', 'acme')"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster (e.g., 'duplo-ai-eks')"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Defaults to latest stable if null."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
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
  description = "AMI type for worker nodes"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "cluster_log_types" {
  description = "EKS control plane log types sent to CloudWatch (must include \"audit\" for SOC2)"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Retention (days) for the EKS control plane log group"
  type        = number
}
