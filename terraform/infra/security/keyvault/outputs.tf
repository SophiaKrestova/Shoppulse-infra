output "key_vault_id" {
  value = module.keyvault.resource_id
}

output "key_vault_name" {
  value = var.key_vault_name
}
