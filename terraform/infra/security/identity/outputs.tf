output "resource_id" {
  description = "User Assigned MI resource ID — parent_id for Federated Identity Credential"
  value       = module.workload_identity.resource_id
}

output "client_id" {
  description = "Use in pod annotation azure.workload.identity/client-id"
  value       = module.workload_identity.client_id
}

output "principal_id" {
  description = "Use for Azure RBAC role assignments (Key Vault Secrets User, etc.)"
  value       = module.workload_identity.principal_id
}

output "name" {
  value = module.workload_identity.resource_name
}
