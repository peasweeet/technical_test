#This file contains the main resource blocks for the module. 
#Creating resource blocks here allows you to import variables from the main.tf in the parent directory. 

#Create resource group
resource "azurerm_resource_group" "demo-rg" {
  name     = var.name
  location = var.location
}