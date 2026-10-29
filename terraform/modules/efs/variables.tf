variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'duplo-ai', 'acme')"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "node_sg_id" {
  description = "Worker node security group ID (allowed NFS access)"
  type        = string
}

variable "eks_cluster_sg_id" {
  description = "EKS-managed cluster security group ID attached to all nodes"
  type        = string
}
