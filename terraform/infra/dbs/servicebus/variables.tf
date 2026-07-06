variable "sku" {
  type        = string
  description = "Basic | Standard | Premium"
  default     = "Standard"
}

variable "capacity" {
  type        = number
  description = "Messaging units (Premium only)"
  default     = 0
}

variable "queue_name" {
  type        = string
  description = "Sales events queue name"
  default     = "sales-events"
}
