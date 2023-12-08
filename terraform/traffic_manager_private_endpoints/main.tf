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

resource "azurerm_virtual_network" "vnet-east" {
  name                = "vnet-east"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["172.16.100.0/24"]

  subnet {
    name           = "subnet-east"
    address_prefix = "172.16.100.0/24"
  }
}

resource "azurerm_virtual_network" "vnet-west" {
  name                = "vnet-west"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westus"
  address_space       = ["172.17.100.0/24"]

  subnet {
    name           = "subnet-west"
    address_prefix = "172.17.100.0/24"
  }
}

resource "azurerm_service_plan" "asp-east" {
  name                = "asp-east"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_web_app" "eastapp" {
  name                = "tjsappeast"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp-east.location
  service_plan_id     = azurerm_service_plan.asp-east.id

  site_config {}
}

resource "azurerm_service_plan" "asp-west" {
  name                = "asp-west"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westus"
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_web_app" "rg" {
  name                = "tjsappwest"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westus"
  service_plan_id     = azurerm_service_plan.asp-west.id

  site_config {}
}