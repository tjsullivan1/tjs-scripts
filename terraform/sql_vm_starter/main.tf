terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.71.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-prod-sql"
  location = "Canada East"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-prod-sql"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "sn-prod-sql"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-prod-sql-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig01"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "vm-prod-sql-01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_D2s_v3"

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2022-WS2022"
    sku       = "standard-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name          = "myOSDisk"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "adminuser"
    admin_password = "P@ssw0rd!" # Bad idea in PROD, this is only for lab environments
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }
}

resource "azurerm_virtual_machine_extension" "sql" {
  name                 = "SQLIaasExtension"
  virtual_machine_id   = azurerm_virtual_machine.vm.id
  publisher            = "Microsoft.SqlServer.Management"
  type                 = "SqlIaaSAgent"
  type_handler_version = "2.0"

  auto_upgrade_minor_version = true
}

# Need to make this replicas

resource "azurerm_managed_disk" "sql_data_disk" {
  count = 4 
  name                 = "disk-vm-prod-sql-{$count.index}-data"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1024"
  disk_iops_read_write = "1200"
  disk_mbps_read_write = "25"
}

resource "azurerm_virtual_machine_data_disk_attachment" "add_sql_data_disk" {
    count = 4
  managed_disk_id    = azurerm_managed_disk.sql_data_disk.id
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = "1${count.index}"
  caching            = "ReadOnly"
}

resource "azurerm_managed_disk" "sql_log_disk" {
  name                 = "disk-vm-prod-sql-01-log"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1024"
}

resource "azurerm_virtual_machine_data_disk_attachment" "add_sql_log_disk" {
  managed_disk_id    = azurerm_managed_disk.sql_log_disk.id
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = "20"
  caching            = "None"
}
