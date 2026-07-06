locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
}

module "workload_identity" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version = "0.5.0"

  name                = "${lower(var.project_name)}-workload"
  location            = local.location
  resource_group_name = local.resource_group_name

  tags = {
    project     = var.project_name
    environment = var.environment
    purpose     = "workload-identity"
  }
}
