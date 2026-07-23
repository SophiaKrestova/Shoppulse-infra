locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  pe_subnet_id        = data.terraform_remote_state.network.outputs.subnet_ids["pe"].resource_id
  vnet_id             = data.terraform_remote_state.network.outputs.virtual_network_id
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${lower(var.project_name)}-redis-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = local.vnet_id
}

resource "azurerm_managed_redis" "this" {
  name                = "${lower(var.project_name)}-redis"
  resource_group_name = local.resource_group_name
  location            = local.location

  sku_name                  = var.sku_name
  high_availability_enabled = var.high_availability_enabled
  public_network_access     = "Disabled"

  default_database {
    clustering_policy = "EnterpriseCluster"
    eviction_policy   = "AllKeysLRU"
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}

resource "azurerm_private_endpoint" "redis" {
  name                = "pe-${lower(var.project_name)}-redis"
  location            = local.location
  resource_group_name = local.resource_group_name
  subnet_id           = local.pe_subnet_id

  private_service_connection {
    name                           = "pse-${lower(var.project_name)}-redis"
    private_connection_resource_id = azurerm_managed_redis.this.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
