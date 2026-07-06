locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  aks_subnet_id       = data.terraform_remote_state.network.outputs.subnet_ids["aks"].resource_id
  appgw_subnet_id     = data.terraform_remote_state.network.outputs.subnet_ids["appgw"].resource_id
  workload_mi_id      = data.terraform_remote_state.identity.outputs.resource_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${lower(var.project_name)}-aks"
  location            = local.location
  resource_group_name = local.resource_group_name
  dns_prefix          = "${lower(var.project_name)}-aks"

  default_node_pool {
    name           = "default"
    vm_size        = var.node_vm_size
    vnet_subnet_id = local.aks_subnet_id
    node_count     = var.node_count
  }

  identity {
    type = "SystemAssigned"
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true
  azure_policy_enabled      = true

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    outbound_type  = "loadBalancer"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  ingress_application_gateway {
    gateway_name = "${lower(var.project_name)}-appgw"
    subnet_id    = local.appgw_subnet_id
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

resource "azurerm_federated_identity_credential" "workloads" {
  for_each = var.service_accounts

  name                = "${lower(var.project_name)}-${each.key}-fic"
  resource_group_name = local.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id           = local.workload_mi_id
  subject             = "system:serviceaccount:${var.k8s_namespace}:${each.key}"
}

resource "azurerm_role_assignment" "aks_appgw_contributor" {
  scope                            = data.terraform_remote_state.base.outputs.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_kubernetes_cluster.this.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_vnet_contributor" {
  scope                            = data.terraform_remote_state.network.outputs.virtual_network_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  count = try(data.terraform_remote_state.acr.outputs.acr_id, null) != null ? 1 : 0

  scope                            = data.terraform_remote_state.acr.outputs.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
