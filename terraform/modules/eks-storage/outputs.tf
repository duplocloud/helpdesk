output "storage_class_name" {
  description = "Kubernetes StorageClass name for EFS"
  value       = kubernetes_storage_class_v1.efs.metadata[0].name
}
