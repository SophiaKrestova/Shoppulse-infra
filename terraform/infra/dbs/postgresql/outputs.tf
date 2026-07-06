output "postgresql_server_id" {
  value = module.postgresql.resource_id
}

output "postgresql_fqdn" {
  value = module.postgresql.fqdn
}

output "database_name" {
  value = var.database_name
}

output "administrator_login" {
  value = var.administrator_login
}
