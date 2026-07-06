variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for ShopPulse workloads"
  default     = "shoppulse"
}

variable "service_accounts" {
  type        = map(string)
  description = "SA name -> description; each gets a Federated Identity Credential"
  default = {
    api        = "backend API"
    worker     = "KEDA worker"
    front-end  = "web UI"
  }
}

variable "node_count" {
  type    = number
  default = 1
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}
