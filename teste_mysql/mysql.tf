# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg-mysql" {
  name     = "rg-mysql"
  location = "East US"
}

# Create a virtual network within the resource group with a virtual machine

# Create virtual network
resource "azurerm_virtual_network" "vn-aula-fs" {
  name                = "vn-aula-fs"
  location            = azurerm_resource_group.rg-mysql.location
  resource_group_name = azurerm_resource_group.rg-mysql.name
  address_space       = ["10.0.0.0/16"]
}

# Create subnet
resource "azurerm_subnet" "sub-aula-fs" {
  name                 = "sub-aula-fs"
  resource_group_name  = azurerm_resource_group.rg-mysql.name
  virtual_network_name = azurerm_virtual_network.vn-aula-fs.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "ip-aula-fs" {
  name                = "ip-aula-fs"
  resource_group_name = azurerm_resource_group.rg-mysql.name
  location            = azurerm_resource_group.rg-mysql.location
  allocation_method   = "Static"

  tags = {
    environment = "ip de acesso a maquina"   
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ngs-aula-fs" {
  name                = "ngs-aula-fs"
  location            = azurerm_resource_group.rg-mysql.location
  resource_group_name = azurerm_resource_group.rg-mysql.name

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

  security_rule {
        name                       = "mysql"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3306"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

  tags = {
    environment = "regras de seguranca"
  }
}

# Create network interface
resource "azurerm_network_interface" "ni-aula-fs" {
  name                = "ni-aula-fs"
  location            = azurerm_resource_group.rg-mysql.location
  resource_group_name = azurerm_resource_group.rg-mysql.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub-aula-fs.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-aula-fs.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nisga-aula-fs" {
    network_interface_id      = azurerm_network_interface.ni-aula-fs.id
    network_security_group_id = azurerm_network_security_group.ngs-aula-fs.id
}

# Create virtual machine
resource "azurerm_virtual_machine" "vm-aula-fs" {
  name                  = "vm-aula-fs"
  location              = azurerm_resource_group.rg-mysql.location
  resource_group_name   = azurerm_resource_group.rg-mysql.name
  network_interface_ids = [azurerm_network_interface.ni-aula-fs.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "dsk-aula-fs"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "vm-aula-fs"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

resource "azurerm_mysql_server" "install_mysql" {
  name                = "install_mysql"
  location            = azurerm_resource_group.rg-mysql.location
  resource_group_name = azurerm_resource_group.rg-mysql.name

  administrator_login          = "adm"
  administrator_login_password = "Password1234!"

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

#show ip on console
output "publicip-vm-aula-fs" {
  value = azurerm_public_ip.ip-aula-fs.ip_address
}
