output "cluster_endpoint" {
  description = "DocumentDB cluster (writer) endpoint — VPC-internal only"
  value       = aws_docdb_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "DocumentDB cluster reader endpoint"
  value       = aws_docdb_cluster.this.reader_endpoint
}

output "port" {
  description = "DocumentDB port"
  value       = aws_docdb_cluster.this.port
}

output "master_username" {
  description = "Master username"
  value       = aws_docdb_cluster.this.master_username
}

output "master_secret_arn" {
  description = "Secrets Manager ARN holding the master credentials"
  value       = aws_secretsmanager_secret.master.arn
}

output "security_group_id" {
  description = "DocumentDB security group ID"
  value       = aws_security_group.this.id
}

output "connection_string" {
  description = "mongodb:// connection string for the Helpdesk chart (secrets.mongoDbConnectionString)"
  value       = local.connection_string
  sensitive   = true
}
