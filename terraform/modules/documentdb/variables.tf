variable "name_prefix" {
  description = "Prefix for all DocumentDB resource names/identifiers (e.g. the EKS cluster name)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,40}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, start with a letter, max 41 chars."
  }
}

variable "vpc_id" {
  description = "VPC the Helpdesk EKS cluster runs in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DocumentDB subnet group (must span at least 2 AZs)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "DocumentDB needs private subnets in at least 2 Availability Zones."
  }
}

variable "source_security_group_ids" {
  description = "Security groups allowed to reach DocumentDB on 27017 — the worker node SGs only, never ALB/bastion SGs"
  type        = list(string)
}

variable "master_username" {
  description = "Master username (matches the bundled-MongoDB rootUser)"
  type        = string
  default     = "helpdesk"
}

variable "instance_class" {
  description = "Instance class for each DocumentDB instance"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of DocumentDB instances (1 = single writer, 2+ adds failover replicas)"
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Pinned DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "backup_retention_period" {
  description = "Days to retain automated backups (1-35)"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily UTC backup window (HH:MM-HH:MM)"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly UTC maintenance window (ddd:HH:MM-ddd:HH:MM)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Prevent the cluster from being deleted until this is turned off"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when the cluster is destroyed"
  type        = bool
  default     = false
}
