variable "sku_name" {
  type        = string
  description = "Basic | Standard | Premium"
  default     = "Basic"
}

variable "capacity" {
  type        = number
  description = "Cache size (0 for Basic)"
  default     = 0
}
