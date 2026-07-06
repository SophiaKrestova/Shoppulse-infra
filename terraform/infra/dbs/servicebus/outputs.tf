output "servicebus_namespace_id" {
  value = module.servicebus.resource_id
}

output "queue_name" {
  value = var.queue_name
}
