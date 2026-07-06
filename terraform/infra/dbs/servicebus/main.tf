locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  pe_subnet_id        = data.terraform_remote_state.network.outputs.subnet_ids["pe"].resource_id
  vnet_id             = data.terraform_remote_state.network.outputs.virtual_network_id
}

resource "azurerm_private_dns_zone" "servicebus" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "servicebus" {
  name                  = "${lower(var.project_name)}-sb-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.servicebus.name
  virtual_network_id    = local.vnet_id
}

module "servicebus" {
  source  = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "0.4.0"

  name                = "${lower(var.project_name)}-messaging"
  location            = local.location
  resource_group_name = local.resource_group_name

  sku      = var.sku
  capacity = var.capacity

  public_network_access_enabled = false

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.servicebus.id]
    }
  }

  queues = {
    (var.queue_name) = {
      max_size_in_megabytes = 1024
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
