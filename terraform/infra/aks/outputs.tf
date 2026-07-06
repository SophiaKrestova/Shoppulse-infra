output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "Used by Federated Identity Credentials"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "workload_identity_client_id" {
  description = "Annotate K8s ServiceAccounts: azure.workload.identity/client-id"
  value       = data.terraform_remote_state.identity.outputs.client_id
}

output "acr_login_server" {
  description = "Target registry for image push/pull (null until acr stack is applied)"
  value       = try(data.terraform_remote_state.acr.outputs.acr_login_server, null)
}

output "federated_credentials" {
  value = {
    for k, v in azurerm_federated_identity_credential.workloads : k => {
      name    = v.name
      subject = v.subject
    }
  }
}
