output "redis_id" {
  value = azurerm_managed_redis.this.id
}

output "redis_hostname" {
  value     = azurerm_managed_redis.this.hostname
  sensitive = true
}
