output "servicebus_namespace_id" {
  value = module.servicebus.resource_id
}

output "queue_name" {
  value = var.queue_name
}

output "primary_connection_string" {
  description = "Namespace primary connection string (sensitive)"
  value       = module.servicebus.resource.default_primary_connection_string
  sensitive   = true
}
