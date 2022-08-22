# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# Configure the Azure resource group
resource "azurerm_resource_group" "demo-rg" {
  name     = "myTFResourceGroup"
  location = "westus3"
}

#Creating the Azure resource group with module
module "resource_group" {
  source = "./modules/resource_group"

  #variables 

  name = "rg-demo"
  location = "westus3"
}

#Creating User Assigned Identity
resource "azurerm_user_assigned_identity" "demo-identity" {
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  name = "Owner"
}

#Creating the Azure storage account
resource "azurerm_storage_account" "demo-sa" {
  name = "storeaccrebeccah"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

#Creating the Azure virtual network
resource "azurerm_virtual_network" "demo-vnet" {
  name = "demo-network"
  location = module.resource_group.location
  resource_group_name = module.resource_group.name
  address_space = ["10.0.0.0/16"]
}

#Creating an Azure subnet for the VMs
resource "azurerm_subnet" "vm-subnet" {
  name = "vm-subnet"
  resource_group_name  = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name
  address_prefixes = ["10.0.1.0/24"]
}

#Creating an Azure subnet for the Application Gateway 
resource "azurerm_subnet" "frontend" {
  name = "frontend-subnet"
  resource_group_name = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name
  address_prefixes = ["10.0.2.0/24"]
}

#Creating the Azure Network Security Group
resource "azurerm_network_security_group" "demo-nsg" {
  name = "network-security-group"
  location = module.resource_group.location
  resource_group_name = module.resource_group.name

  security_rule {
    name = "SSH"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "x.x.x.x" #Change to your home/workplace's public IP address for administrative access 
    destination_address_prefix = "10.0.1.0/24" #change to IP of VM subnet
  }
}

resource "azurerm_subnet_network_security_group_association" "demo-nsg-association" {
  subnet_id = azurerm_subnet.vm-subnet.id
  network_security_group_id = azurerm_network_security_group.demo-nsg.id
}

#Creating a public IP for VM 1
resource "azurerm_public_ip" "vm1" {
  name = "vm1"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  allocation_method = "Static"
  sku = "Standard"
}

#Creating a public IP for VM 2
resource "azurerm_public_ip" "vm2" {
  name = "vm2"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  allocation_method   = "Static"
  sku = "Standard"
}

#Creating NIC for VM 1
resource "azurerm_network_interface" "demo-nic1" {
  name = "demo-nic1"
  location = module.resource_group.location
  resource_group_name = module.resource_group.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.vm1.id
  }
}

#Creating NIC for VM 2
resource "azurerm_network_interface" "demo-nic2" {
  name = "demo-nic2"
  location = module.resource_group.location
  resource_group_name = module.resource_group.name

  ip_configuration {
    name= "internal"
    subnet_id = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.vm2.id
  }
}

#Creating the VMs from Shared Gallery Image
data "azurerm_shared_image" "shared-image" {
  name = "linuxfancyrats"
  gallery_name = "fancyrats"
  resource_group_name = "myTFResourceGroup"
}

#VM 1
resource "azurerm_linux_virtual_machine" "vm1" {
  name = "vm1"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  size = "Standard_B1s"
  network_interface_ids = [azurerm_network_interface.demo-nic1.id]
  zone = 2
  disable_password_authentication = false
  admin_username = "adminuser"
  admin_password = "P@ssword123!"

  source_image_id = data.azurerm_shared_image.shared-image.id

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

#VM 2
resource "azurerm_linux_virtual_machine" "vm2" {
  name = "vm2"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location
  size = "Standard_B1s"
  network_interface_ids = [azurerm_network_interface.demo-nic2.id]
  zone = 3
  disable_password_authentication = false
  admin_username = "adminuser"
  admin_password = "P@ssword123!"
  
  source_image_id = data.azurerm_shared_image.shared-image.id

  os_disk {
    caching                   = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

#Creating the Azure application gateway
#Public IP for the App Gateway
# Configure a public IP address 
resource "azurerm_public_ip" "demo-ip" {
  name                = "demo-public-ip"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  allocation_method   = "Static"
  sku = "Standard"
}

#App Gateway
resource "azurerm_application_gateway" "appgateway" {
  name = "demo-appgateway"
  resource_group_name = module.resource_group.name
  location = module.resource_group.location

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
    capacity = 2
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.demo-identity.id]
  }

  gateway_ip_configuration {
    name = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = "frontend-port"
    port = 80
  }

  frontend_ip_configuration {
    name = "frontend-ip-config" 
    public_ip_address_id = azurerm_public_ip.demo-ip.id
  }

  backend_address_pool {
   name = "backend-address-pool" 
   ip_addresses = [ 
     "10.0.1.4", 
     "10.0.1.5" ]
  }

  backend_http_settings {
    name =  "backend-http-settings" 
    cookie_based_affinity = "Disabled"
    path = "/path1/"
    port = 80
    protocol = "Http"
    request_timeout = 60
  }
  http_listener {
    name = "http-listener" 
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name = "frontend-port"
    protocol = "Http"
  }

  request_routing_rule {
    name = "request-routing-rule"
    rule_type = "Basic"
    http_listener_name = "http-listener"
    backend_address_pool_name  = "backend-address-pool" 
    backend_http_settings_name = "backend-http-settings"
  }
}
