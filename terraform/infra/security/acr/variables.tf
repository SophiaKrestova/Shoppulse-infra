variable "acr_name" {
  type        = string
  description = "Globally unique ACR name — set in env/acr.tfvars"
}

variable "sku" {
  type        = string
  description = "Basic | Standard | Premium"
  default     = "Premium"
}
