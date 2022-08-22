# This file contains the outputted data variables from the module.data
#Specifying data outputs allows these to be referenced by other modules.

output "name" {
  value = azurerm_resource_group.demo-rg.name
}

output "location" {
  value = azurerm_resource_group.demo-rg.location
}

output "id" {
  value = azurerm_resource_group.demo-rg.id
}