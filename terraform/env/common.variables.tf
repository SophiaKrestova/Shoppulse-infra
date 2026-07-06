variable "subscription_id" {
  type        = string
  description = "Azure subscription ID — value in env/common.tfvars"
}

variable "resource_group_location" {
  type        = string
  description = "Azure region — value in env/common.tfvars"
}

variable "project_name" {
  type        = string
  description = "Project name prefix for resources"
  default     = "ShopPulse"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "dev"
}
