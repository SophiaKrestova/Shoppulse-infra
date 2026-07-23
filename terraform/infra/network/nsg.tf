locals {
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  location            = data.terraform_remote_state.base.outputs.resource_group_location
}

module "nsg_appgw" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = "${lower(var.project_name)}-appgw-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rules = {
    allow_gateway_manager = {
      name                       = "AllowGatewayManager"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    }
    allow_azure_load_balancer = {
      name                       = "AllowAzureLoadBalancer"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
    allow_https_internet = {
      name                       = "AllowHttpsInternet"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
    allow_http_internet = {
      name                       = "AllowHttpInternet"
      priority                   = 125
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    tier        = "appgw"
  }
}

module "nsg_aks" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = "${lower(var.project_name)}-aks-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rules = {
    allow_appgw_to_ingress = {
      name                       = "AllowAppGwToIngress"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["80", "443"]
      source_address_prefix      = "10.0.1.0/24"
      destination_address_prefix = "*"
    }
    allow_azure_load_balancer = {
      name                       = "AllowAzureLoadBalancer"
      priority                   = 105
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
    allow_vnet_inbound = {
      name                       = "AllowVnetInbound"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
    deny_internet_inbound = {
      name                       = "DenyInternetInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    tier        = "aks"
  }
}

module "nsg_pe" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = "${lower(var.project_name)}-pe-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rules = {
    allow_aks_to_private_endpoints = {
      name                       = "AllowAksToPrivateEndpoints"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["10000", "5671", "5672", "443"]
      source_address_prefix      = "10.0.4.0/22"
      destination_address_prefix = "*"
    }
    deny_internet_inbound = {
      name                       = "DenyInternetInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    tier        = "private-endpoints"
  }
}

module "nsg_postgres" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.1"

  name                = "${lower(var.project_name)}-postgres-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rules = {
    allow_aks_to_postgres = {
      name                       = "AllowAksToPostgres"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "5432"
      source_address_prefix      = "10.0.4.0/22"
      destination_address_prefix = "*"
    }
    deny_internet_inbound = {
      name                       = "DenyInternetInbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }

  tags = {
    project     = var.project_name
    environment = var.environment
    tier        = "postgres"
  }
}
