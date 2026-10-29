variable "name_prefix" {
  description = "Prefix for resource names (e.g., 'duplo-ai', 'acme')"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "log_retention_days" {
  description = "Retention (days) for the VPC flow log group"
  type        = number
}
