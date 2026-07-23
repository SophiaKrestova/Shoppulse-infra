variable "sku_name" {
  type        = string
  description = "Azure Managed Redis SKU (e.g. Balanced_B0)"
  default     = "Balanced_B0"
}

variable "high_availability_enabled" {
  type        = bool
  description = "HA; Balanced_B0 does not support HA"
  default     = false
}
