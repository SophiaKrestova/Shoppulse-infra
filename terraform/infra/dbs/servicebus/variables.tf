variable "sku" {
  type        = string
  description = "Basic | Standard | Premium — Premium required for private endpoints"
  default     = "Premium"
}

variable "capacity" {
  type        = number
  description = "Messaging units (Premium only)"
  default     = 1
}

variable "queue_name" {
  type        = string
  description = "Sales events queue name"
  default     = "sales-events"
}
