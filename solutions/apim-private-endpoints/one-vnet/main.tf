terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.31.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~> 3.1.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = false
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {
}

provider "random" {
}


data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  lower   = true
  number  = true
  upper   = false
  special = false
}

resource "azurerm_resource_group" "vnetapim" {
  name     = "rg-${var.disambiguation}-${random_string.suffix.result}-main"
  location = var.location

  # Uncomment for Demo on Challenges
  lifecycle {
    ignore_changes = [tags, ]
  }
}

# Will uncomment this when we get to the second VNet
#resource "azurerm_resource_group" "tjs" {
#name     = "rg-${var.disambiguation}-${random_string.suffix.result}"
#location = var.location

# Uncomment for Demo on Challenges
# lifecycle {
#   ignore_changes = [ tags, ]
# }
#}

resource "azurerm_virtual_network" "vnetapim" {
  name                = "vnet-${var.disambiguation}-${random_string.suffix.result}-main"
  address_space       = ["10.100.0.0/16"]
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-appgw"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.0.0/24"]
}

resource "azurerm_subnet" "apim" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-apim"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_subnet" "function" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-function"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.2.0/24"]
}

resource "azurerm_subnet" "function2" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-function2"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.3.0/24"]
}

resource "azurerm_subnet" "vms" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-vms"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.4.0/24"]
}

resource "azurerm_network_interface" "tester" {
  name                = "nic-${var.disambiguation}-${random_string.suffix.result}-tester"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "tester" {
  name                = "vm-${var.disambiguation}-${random_string.suffix.result}-tester"
  resource_group_name = azurerm_resource_group.vnetapim.name
  location            = azurerm_resource_group.vnetapim.location
  size                = "Standard_B4ms"
  admin_username      = "tjs"
  network_interface_ids = [
    azurerm_network_interface.tester.id,
  ]

  admin_ssh_key {
    username   = "tjs"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-LTS"
    version   = "latest"
  }
}

resource "azurerm_api_management" "apim" {
  name                = "apim-${var.disambiguation}-${random_string.suffix.result}"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name
  publisher_name      = "Sullivan Enterprises"
  publisher_email     = "tim@sullivanenterprises.org"

  sku_name = "Developer_1"

  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }
}

resource "azurerm_storage_account" "sa" {
  name                     = "sa${var.disambiguation}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.vnetapim.name
  location                 = azurerm_resource_group.vnetapim.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_service_plan" "aspfunc1" {
  location            = var.location
  name                = "asp-${var.disambiguation}-${random_string.suffix.result}-func1"
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.vnetapim.name
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "func1" {
  builtin_logging_enabled    = false
  client_certificate_mode    = "Required"
  location                   = var.location
  name                       = "func-${var.disambiguation}-${random_string.suffix.result}-func1"
  resource_group_name        = azurerm_resource_group.vnetapim.name
  service_plan_id            = azurerm_service_plan.aspfunc1.id
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_account_name       = azurerm_storage_account.sa.name


  identity {

    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }

  site_config {
    ftps_state    = "AllAllowed"
    http2_enabled = true
    application_stack {
      python_version = "3.9"
    }
  }
  depends_on = [
    azurerm_service_plan.aspfunc1,
  ]
}

resource "azurerm_private_dns_zone" "vnetapim" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.vnetapim.name
}

resource "azurerm_private_endpoint" "func1" {
  name                = "pe-func-${var.disambiguation}-${random_string.suffix.result}-func1"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name
  subnet_id           = azurerm_subnet.function.id
  #private_dns_zone_id = azurerm_private_dns_zone.vnetapim.id

  #dns_config {
  #name    = "func-${var.disambiguation}-${random_string.suffix.result}-func1"
  #records = [
  #"func-${var.disambiguation}-${random_string.suffix.result}-func1.privatelink.azurewebsites.net"
  #]
  #}

  private_service_connection {
    name                           = "psc-func-${var.disambiguation}-${random_string.suffix.result}-func1"
    private_connection_resource_id = azurerm_linux_function_app.func1.id
    subresource_names              = []
    is_manual_connection           = false
  }
}