variable "sku_name" {
  type        = string
  description = "Azure Managed Redis SKU (classic Premium P1 is unavailable on this subscription)"
  default     = "Balanced_B0"
}

variable "high_availability_enabled" {
  type    = bool
  default = false
}
