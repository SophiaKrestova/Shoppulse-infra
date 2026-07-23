output "key_vault_id" {
  value = module.keyvault.resource_id
}

output "key_vault_name" {
  value = var.key_vault_name
}

output "postgres_password" {
  value     = random_password.postgres.result
  sensitive = true
}

output "redis_password" {
  value     = random_password.redis.result
  sensitive = true
}

output "servicebus_connection_string" {
  value     = random_password.servicebus.result
  sensitive = true
}
