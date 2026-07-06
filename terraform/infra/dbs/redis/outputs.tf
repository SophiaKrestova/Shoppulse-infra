output "redis_id" {
  value = module.redis.resource_id
}

output "redis_hostname" {
  value = module.redis.resource.hostname
}
