output "virtual_network_id" {
  value = module.virtual_network.resource_id
}

output "virtual_network_name" {
  value = module.virtual_network.name
}

output "subnet_ids" {
  value = module.virtual_network.subnets
}

output "resource_group_id" {
  description = "Parent resource group ID (what older docs call parent_id)"
  value       = data.terraform_remote_state.base.outputs.resource_group_id
}

output "nsg_ids" {
  description = "Network Security Group IDs per tier"
  value = {
    appgw    = module.nsg_appgw.resource_id
    aks      = module.nsg_aks.resource_id
    pe       = module.nsg_pe.resource_id
    postgres = module.nsg_postgres.resource_id
  }
}
