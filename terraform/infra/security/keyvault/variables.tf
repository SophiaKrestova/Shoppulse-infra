variable "key_vault_name" {
  type        = string
  description = "3-24 chars, globally unique — set in env/keyvault.tfvars"
}

variable "secrets" {
  type        = map(string)
  description = "Key Vault secret name -> value — set in env/keyvault.tfvars"
  sensitive   = true
}
