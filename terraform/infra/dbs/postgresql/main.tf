locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  pe_subnet_id        = data.terraform_remote_state.network.outputs.subnet_ids["pe"].resource_id
  vnet_id             = data.terraform_remote_state.network.outputs.virtual_network_id
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "${lower(var.project_name)}-pgsql-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = local.vnet_id
}

module "postgresql" {
  source  = "Azure/avm-res-dbforpostgresql-flexibleserver/azurerm"
  version = "0.1.4"

  name                = "${lower(var.project_name)}-pgsql"
  location            = local.location
  resource_group_name = local.resource_group_name

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  server_version = var.server_version
  sku_name       = var.sku_name
  storage_mb     = var.storage_mb
  zone           = 1

  public_network_access_enabled = false
  high_availability             = null

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.postgresql.id]
    }
  }

  databases = {
    app = {
      name      = var.database_name
      charset   = "UTF8"
      collation = "en_US.utf8"
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
