# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
  disable_terraform_partner_id = false
  partner_id      = "fa9e3e10-7528-4589-9c7a-a9b1127598d2"
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "scagroup" {
    name     = "scaResourceGroup"
    location = "westus2"

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "scanetwork" {
    name                = "Vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westus2"
    resource_group_name = azurerm_resource_group.scagroup.name

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Create subnet
resource "azurerm_subnet" "scasubnet" {
    name                 = "scaSubnet"
    resource_group_name  = azurerm_resource_group.scagroup.name
    virtual_network_name = azurerm_virtual_network.scanetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "scapublicip" {
    name                         = "scaPublicIP"
    location                     = "westus2"
    resource_group_name          = azurerm_resource_group.scagroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "scansg" {
    name                = "scaNetworkSecurityGroup"
    location            = "westus2"
    resource_group_name = azurerm_resource_group.scagroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Create network interface
resource "azurerm_network_interface" "scanic" {
    name                      = "scaNIC"
    location                  = "westus2"
    resource_group_name       = azurerm_resource_group.scagroup.name

    ip_configuration {
        name                          = "scaNicConfiguration"
        subnet_id                     = azurerm_subnet.scasubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.scapublicip.id
    }

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.scanic.id
    network_security_group_id = azurerm_network_security_group.scansg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.scagroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "scastorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.scagroup.name
    location                    = "westus2"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Supportconfig Analyzer"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "scavm" {
    name                  = "scaVM"
    location              = "westus2"
    resource_group_name   = azurerm_resource_group.scagroup.name
    network_interface_ids = [azurerm_network_interface.scanic.id]
    size                  = "Standard_DS2_v2"

    os_disk {
        name              = "scaOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "SUSE"
        offer     = "openSUSE-Leap"
        sku       = "15-2"
        version   = "latest"
    }

    computer_name  = "scavm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.scastorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Supportconfig Analyzer"
    }
}
