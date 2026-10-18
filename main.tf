terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "2703619c-b393-4083-9ceb-037cbd957aa0"
}

############################
# Variables
############################

variable "location" {
  type    = string
  default = "centralindia"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2as_v5"
}

variable "vm_zone" {
  type    = string
  default = null
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
}

############################
# Resource group and network
############################

resource "azurerm_resource_group" "JAF" {
  name     = "lab-jkl-3"
  location = var.location
}

resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = azurerm_resource_group.JAF.location
  resource_group_name = azurerm_resource_group.JAF.name
}

resource "azurerm_network_security_group" "hr_nsg" {
  name                = "hr-nsg"
  location            = azurerm_resource_group.JAF.location
  resource_group_name = azurerm_resource_group.JAF.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "lab-vnet"
  location            = azurerm_resource_group.JAF.location
  resource_group_name = azurerm_resource_group.JAF.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name             = "web-subnet"
    address_prefixes = ["10.0.1.0/24"]
    security_group   = azurerm_network_security_group.web_nsg.id
  }

  subnet {
    name             = "hr-subnet"
    address_prefixes = ["10.0.2.0/24"]
    security_group   = azurerm_network_security_group.hr_nsg.id
  }
}

resource "azurerm_network_security_rule" "ssh" {
  name                       = "Allow-SSH"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.JAF.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_network_security_rule" "http" {
  name                       = "Allow-HTTP"
  priority                   = 110
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.JAF.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_public_ip" "pip" {
  name                = "lab-pip"
  location            = azurerm_resource_group.JAF.location
  resource_group_name = azurerm_resource_group.JAF.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "lab-nic"
  location            = azurerm_resource_group.JAF.location
  resource_group_name = azurerm_resource_group.JAF.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = one([for s in azurerm_virtual_network.vnet.subnet : s.id if s.name == "web-subnet"])
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

############################
# Virtual machine
############################

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "lab-vm"
  resource_group_name = azurerm_resource_group.JAF.name
  location            = azurerm_resource_group.JAF.location

  size = var.vm_size
  zone = var.vm_zone

  admin_username                  = "azureuser"
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.JAF.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "public_ip_name" {
  value = azurerm_public_ip.pip.name
}