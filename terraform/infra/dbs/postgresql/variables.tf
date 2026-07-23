variable "administrator_login" {
  type        = string
  description = "PostgreSQL admin login — set in env/postgresql.tfvars"
}

variable "server_version" {
  type        = string
  description = "PostgreSQL major version"
  default     = "16"
}

variable "sku_name" {
  type        = string
  description = "Compute SKU — GP_Standard_D2s_v3 for task"
  default     = "GP_Standard_D2s_v3"
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
