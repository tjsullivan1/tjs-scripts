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

resource "azurerm_resource_group" "func1" {
name     = "rg-${var.disambiguation}-${random_string.suffix.result}-func1"
location = var.location

 lifecycle {
   ignore_changes = [ tags, ]
 }
}

resource "azurerm_resource_group" "func2" {
name     = "rg-${var.disambiguation}-${random_string.suffix.result}-func2"
location = var.location

 lifecycle {
   ignore_changes = [ tags, ]
 }
}

resource "azurerm_virtual_network" "vnetapim" {
  name                = "vnet-${var.disambiguation}-${random_string.suffix.result}-main"
  address_space       = ["10.100.0.0/22"]
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

resource "azurerm_subnet" "vms" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-vms"
  resource_group_name  = azurerm_resource_group.vnetapim.name
  virtual_network_name = azurerm_virtual_network.vnetapim.name
  address_prefixes     = ["10.100.2.0/24"]
}

resource "azurerm_virtual_network" "func1" {
  name                = "vnet-${var.disambiguation}-${random_string.suffix.result}-func1"
  address_space       = ["10.100.5.0/24", "10.101.5.0/24"]
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.func1.name
}

resource "azurerm_subnet" "function" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-function"
  resource_group_name  = azurerm_resource_group.func1.name
  virtual_network_name = azurerm_virtual_network.func1.name
  address_prefixes     = ["10.100.5.0/24"]
}

resource "azurerm_subnet" "vms_function1" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-vms"
  resource_group_name  = azurerm_resource_group.func1.name
  virtual_network_name = azurerm_virtual_network.func1.name
  address_prefixes     = ["10.101.5.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "func1-vms" {
  subnet_id                 = azurerm_subnet.vms_function1.id
  network_security_group_id = "/subscriptions/f33f4d2a-99ac-47ab-8142-a5f6f768020f/resourceGroups/rg-tjsapi-p86x-main/providers/Microsoft.Network/networkSecurityGroups/nsg-vms"
}

resource "azurerm_subnet_network_security_group_association" "func2-vms" {
  subnet_id                 = azurerm_subnet.vms_function2.id
  network_security_group_id = "/subscriptions/f33f4d2a-99ac-47ab-8142-a5f6f768020f/resourceGroups/rg-tjsapi-p86x-main/providers/Microsoft.Network/networkSecurityGroups/nsg-vms"
}

resource "azurerm_virtual_network" "func2" {
  name                = "vnet-${var.disambiguation}-${random_string.suffix.result}-func2"
  address_space       = ["10.100.4.0/24", "10.101.4.0/24"]
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.func2.name
}

resource "azurerm_subnet" "function2" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-function2"
  resource_group_name  = azurerm_resource_group.func2.name
  virtual_network_name = azurerm_virtual_network.func2.name
  address_prefixes     = ["10.100.4.0/24"]
}

resource "azurerm_subnet" "vms_function2" {
  name                 = "snet-${var.disambiguation}-${random_string.suffix.result}-vms"
  resource_group_name  = azurerm_resource_group.func2.name
  virtual_network_name = azurerm_virtual_network.func2.name
  address_prefixes     = ["10.101.4.0/24"]
}


resource "azurerm_public_ip" "tester-pip" {
allocation_method = "Dynamic"
name                = "pip-${var.disambiguation}-${random_string.suffix.result}-tester" 
resource_group_name = azurerm_resource_group.vnetapim.name
location            = azurerm_resource_group.vnetapim.location

}

resource "azurerm_network_interface" "tester" {
  name                = "nic-${var.disambiguation}-${random_string.suffix.result}-tester"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vms.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tester-pip.id
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

module "tester-func1" {
  source = "../modules/tester-vm"
  
  name = "func1"
  resource_group = azurerm_resource_group.func1.name
  location = azurerm_resource_group.func1.location
  subnet_id = azurerm_subnet.vms_function1.id
}

module "tester-func2" {
  source = "../modules/tester-vm"
  
  name = "func2"
  resource_group = azurerm_resource_group.func2.name
  location = azurerm_resource_group.func2.location
  subnet_id = azurerm_subnet.vms_function2.id
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
  sku_name            = "EP1"
}

resource "azurerm_linux_function_app" "func1" {
  builtin_logging_enabled    = false
  client_certificate_mode    = "Required"
  location                   = var.location
  name                       = "func-${var.disambiguation}-${random_string.suffix.result}-func1"
  resource_group_name        = azurerm_resource_group.func1.name
  service_plan_id            = azurerm_service_plan.aspfunc1.id
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_account_name       = azurerm_storage_account.sa.name


  identity {

    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    BUILD_FLAGS = "UseExpressBuild"
    ENABLE_ORYX_BUILD = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "1"
    XDG_CACHE_HOME = "/tmp/.cache"
    function_name = "1"
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
resource "azurerm_linux_function_app" "func2" {
  builtin_logging_enabled    = false
  client_certificate_mode    = "Required"
  location                   = var.location
  name                       = "func-${var.disambiguation}-${random_string.suffix.result}-func2"
  resource_group_name        = azurerm_resource_group.func2.name
  service_plan_id            = azurerm_service_plan.aspfunc1.id
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_account_name       = azurerm_storage_account.sa.name


  identity {

    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    BUILD_FLAGS = "UseExpressBuild"
    ENABLE_ORYX_BUILD = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "1"
    XDG_CACHE_HOME = "/tmp/.cache"
    function_name = "2"
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

resource "azurerm_private_dns_zone_virtual_network_link" "toapimvnet" {
  name                  = "test"
  resource_group_name   = azurerm_resource_group.vnetapim.name
  private_dns_zone_name = azurerm_private_dns_zone.vnetapim.name
  virtual_network_id    = azurerm_virtual_network.vnetapim.id
}

resource "azurerm_private_dns_zone" "function1" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.func1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "tofunc1vnet" {
  name                  = "func1"
  resource_group_name   = azurerm_resource_group.func1.name
  private_dns_zone_name = azurerm_private_dns_zone.function1.name
  virtual_network_id    = azurerm_virtual_network.func1.id
}


resource "azurerm_private_endpoint" "func1" {
  name                = "pe-func-${var.disambiguation}-${random_string.suffix.result}-func1"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name
  subnet_id           = azurerm_subnet.function.id
  private_dns_zone_group {
    name = azurerm_private_dns_zone.vnetapim.name
    private_dns_zone_ids = [
    azurerm_private_dns_zone.vnetapim.id, 
    ]
  }

  private_service_connection {
    name                           = "psc-func-${var.disambiguation}-${random_string.suffix.result}-func1"
    private_connection_resource_id = azurerm_linux_function_app.func1.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "func2" {
  name                = "pe-func-${var.disambiguation}-${random_string.suffix.result}-func2"
  location            = azurerm_resource_group.vnetapim.location
  resource_group_name = azurerm_resource_group.vnetapim.name
  subnet_id           = azurerm_subnet.function2.id
  private_dns_zone_group {
    name = azurerm_private_dns_zone.vnetapim.name
    private_dns_zone_ids = [
    azurerm_private_dns_zone.vnetapim.id,
    ]
  }

  private_service_connection {
    name                           = "psc-func-${var.disambiguation}-${random_string.suffix.result}-func2"
    private_connection_resource_id = azurerm_linux_function_app.func2.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

resource "azurerm_linux_function_app" "func3" {
  builtin_logging_enabled    = false
  client_certificate_mode    = "Required"
  location                   = var.location
  name                       = "func-${var.disambiguation}-${random_string.suffix.result}-func3"
  resource_group_name        = azurerm_resource_group.vnetapim.name
  service_plan_id            = azurerm_service_plan.aspfunc1.id
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  storage_account_name       = azurerm_storage_account.sa.name


  identity {

    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    BUILD_FLAGS = "UseExpressBuild"
    ENABLE_ORYX_BUILD = "true"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "1"
    XDG_CACHE_HOME = "/tmp/.cache"
    function_name = "3"
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

resource "azurerm_virtual_network_peering" "main-1" {
  name                      = "main-1"
  resource_group_name       = azurerm_resource_group.vnetapim.name
  virtual_network_name      = azurerm_virtual_network.vnetapim.name
  remote_virtual_network_id = azurerm_virtual_network.func1.id
}

resource "azurerm_virtual_network_peering" "_1-main" {
  name                      = "1-main"
  resource_group_name       = azurerm_resource_group.func1.name
  virtual_network_name      = azurerm_virtual_network.func1.name
  remote_virtual_network_id = azurerm_virtual_network.vnetapim.id
}

resource "azurerm_virtual_network_peering" "main-2" {
  name                      = "main-2"
  resource_group_name       = azurerm_resource_group.vnetapim.name
  virtual_network_name      = azurerm_virtual_network.vnetapim.name
  remote_virtual_network_id = azurerm_virtual_network.func2.id
}

resource "azurerm_virtual_network_peering" "_2-main" {
  name                      = "2-main"
  resource_group_name       = azurerm_resource_group.func2.name
  virtual_network_name      = azurerm_virtual_network.func2.name
  remote_virtual_network_id = azurerm_virtual_network.vnetapim.id
}