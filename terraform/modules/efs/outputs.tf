output "efs_id" {
  description = "EFS filesystem ID"
  value       = aws_efs_file_system.this.id
}

output "efs_arn" {
  description = "EFS filesystem ARN"
  value       = aws_efs_file_system.this.arn
}

output "efs_dns_name" {
  description = "EFS DNS name"
  value       = aws_efs_file_system.this.dns_name
}
