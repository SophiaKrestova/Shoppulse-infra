variable "administrator_login" {
  type        = string
  description = "PostgreSQL admin login — set in env/postgresql.tfvars"
}

variable "administrator_password" {
  type        = string
  description = "PostgreSQL admin password — set in env/postgresql.tfvars"
  sensitive   = true
}

variable "server_version" {
  type        = string
  description = "PostgreSQL major version"
  default     = "16"
}

variable "sku_name" {
  type        = string
  description = "Burstable SKU for study/dev; bump to GP_Standard_D2s_v3 for prod"
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type        = number
  description = "Storage size in MB"
  default     = 32768
}

variable "database_name" {
  type        = string
  description = "Application database name"
  default     = "shoppulse"
}
