output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "userdata_bucket_name" {
  description = "ai-studio-userdata S3 bucket name"
  value       = aws_s3_bucket.userdata.id
}

output "userdata_bucket_arn" {
  description = "ai-studio-userdata S3 bucket ARN"
  value       = aws_s3_bucket.userdata.arn
}
