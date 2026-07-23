data "azurerm_client_config" "current" {}

locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  pe_subnet_id        = data.terraform_remote_state.network.outputs.subnet_ids["pe"].resource_id
  vnet_id             = data.terraform_remote_state.network.outputs.virtual_network_id
  workload_principal  = data.terraform_remote_state.identity.outputs.principal_id

  secrets_value = {
    "postgres-password"            = random_password.postgres.result
    "redis-password"               = random_password.redis.result
    "servicebus-connection-string" = random_password.servicebus.result
  }
}

resource "random_password" "postgres" {
  length           = 32
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#%*()-_=+[]{}"
}

resource "random_password" "redis" {
  length           = 32
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#%*()-_=+[]{}"
}

resource "random_password" "servicebus" {
  length  = 48
  special = false
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = local.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${lower(var.project_name)}-kv-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = local.vnet_id
}

module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.1"

  name                = var.key_vault_name
  location            = local.location
  resource_group_name = local.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name                       = "standard"
  legacy_access_policies_enabled = false
  public_network_access_enabled  = false
  purge_protection_enabled       = true
  soft_delete_retention_days     = 7

  private_endpoints = {
    primary = {
      subnet_resource_id            = local.pe_subnet_id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.keyvault.id]
    }
  }

  secrets = {
    "postgres-password"            = { name = "postgres-password" }
    "redis-password"               = { name = "redis-password" }
    "servicebus-connection-string" = { name = "servicebus-connection-string" }
  }

  secrets_value = local.secrets_value

  role_assignments = {
    deployer_secrets_officer = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.current.object_id
    }
    workload_secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = local.workload_principal
    }
  }

  wait_for_rbac_before_secret_operations = {
    create  = "30s"
    destroy = "0s"
  }

  tags = {
    project     = var.project_name
    environment = var.environment
  }
}
