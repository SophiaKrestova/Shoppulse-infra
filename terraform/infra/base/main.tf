module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.1"

  name     = "ShopPulse-ResGroup"
  location = var.resource_group_location
}
