variable "account_id" {
  description = "AWS account ID used to name the bucket"
  type        = string
}

variable "bucket_name_suffix" {
  description = "Optional suffix appended to the bucket names, for running more than one deployment per AWS account"
  type        = string
  default     = ""
}

variable "lifecycle_enabled" {
  description = "Enable S3 lifecycle rules"
  type        = bool
  default     = false
}

variable "lifecycle_expiration_days" {
  description = "Number of days after which objects expire"
  type        = number
  default     = 90
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent (overwritten/deleted) object versions are permanently removed"
  type        = number
  default     = 90
}
