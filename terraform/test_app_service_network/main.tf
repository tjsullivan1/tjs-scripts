# main.tf
locals {
}

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# Retrieve the virtual network object vnet-fdpo-avd in the resource group rg-avd-fdpo
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

# Create a subnet in the virtual network
resource "azurerm_subnet" "subnet" {
  name                 = "testappsvctf"
  resource_group_name  = var.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["192.168.3.0/24"]

  delegation {
    name = "appsvctf"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
    }
  }
}

# Create an app service plan in the resource group running on Linux
resource "azurerm_service_plan" "appserviceplan" {
  name                = "tf-asp-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type = "Linux"
  sku_name = "P1v3"
}

# Create an app service plan in the resource group running on Linux
resource "azurerm_service_plan" "appserviceplan2" {
  name                = "tf-asp-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type = "Linux"
  sku_name = "P1v3"
}

resource "azurerm_linux_web_app" "webapp1" {
  name                = "tf-lin-webapp1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.appserviceplan.id
  virtual_network_subnet_id = azurerm_subnet.subnet.id
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
  site_config {
  }
}

resource "azurerm_linux_web_app" "webapp2" {
  name                = "tf-lin-webapp2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.appserviceplan.id
  virtual_network_subnet_id = azurerm_subnet.subnet.id
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
  site_config {}
}

resource "azurerm_linux_web_app" "webapp3" {
  name                = "tf-lin-webapp3"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.appserviceplan2.id
  virtual_network_subnet_id = azurerm_subnet.subnet.id
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
  site_config {}
}

resource "azurerm_linux_web_app" "webapp4" {
  name                = "tf-lin-webapp4"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id = azurerm_service_plan.appserviceplan2.id
  virtual_network_subnet_id = azurerm_subnet.subnet.id
  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
  site_config {}
}