output "release_name" {
  description = "Helm release name"
  value       = helm_release.ai_studio.name
}

output "release_status" {
  description = "Helm release status"
  value       = helm_release.ai_studio.status
}

output "values_file_path" {
  description = "Path to the rendered values.yml"
  value       = local_file.values.filename
}
