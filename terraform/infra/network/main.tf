module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.10.0"

  name                = "ShopPulse-VNetwork"
  location            = data.terraform_remote_state.base.outputs.resource_group_location
  resource_group_name = data.terraform_remote_state.base.outputs.resource_group_name
  address_space       = [var.vnet_address_space]

  subnets = {
    appgw = {
      name             = "appgw-subnet"
      address_prefixes = ["10.0.1.0/24"]
      network_security_group = {
        id = module.nsg_appgw.resource_id
      }
    }
    aks = {
      name             = "aks-subnet"
      address_prefixes = ["10.0.4.0/22"]
      network_security_group = {
        id = module.nsg_aks.resource_id
      }
    }
    pe = {
      name             = "pe-subnet"
      address_prefixes = ["10.0.8.0/24"]
      network_security_group = {
        id = module.nsg_pe.resource_id
      }
    }
  }
}
