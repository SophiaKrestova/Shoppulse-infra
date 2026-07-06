locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  pe_subnet_id        = data.terraform_remote_state.network.outputs.subnet_ids["pe"].resource_id
  vnet_id             = data.terraform_remote_state.network.outputs.virtual_network_id
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${lower(var.project_name)}-redis-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = local.vnet_id
}

module "redis" {
  source  = "Azure/avm-res-cache-redis/azurerm"
  version = "0.4.0"

  name                = "${lower(var.project_name)}-redis"
  location            = local.location
  resource_group_name = local.resource_group_name

  sku_name = var.sku_name
  capacity = var.capacity

  public_network_access_enabled = false

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.redis.id]
    }
  }

  redis_configuration = {
    maxmemory_policy = "allkeys-lru"
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
