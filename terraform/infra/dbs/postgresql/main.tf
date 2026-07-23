locals {
  resource_group_name    = data.terraform_remote_state.base.outputs.resource_group_name
  location               = data.terraform_remote_state.base.outputs.resource_group_location
  vnet_id                = data.terraform_remote_state.network.outputs.virtual_network_id
  postgres_subnet_id     = data.terraform_remote_state.network.outputs.subnet_ids["postgres"].resource_id
  administrator_password = data.terraform_remote_state.keyvault.outputs.postgres_password
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
  administrator_password = local.administrator_password

  server_version = var.server_version
  sku_name       = var.sku_name
  storage_mb     = var.storage_mb
  zone           = 1

  delegated_subnet_id           = local.postgres_subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  high_availability             = null

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
