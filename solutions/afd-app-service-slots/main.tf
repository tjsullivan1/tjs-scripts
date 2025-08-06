# main.tf
locals {
    specifier = "slots"
}

resource "azurerm_resource_group" "rg" {
  name     =  "${var.resource_group_name_prefix}-${local.specifier}"
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd-${local.specifier}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name                 = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "ep1" {
  name                     = "ep1-${local.specifier}"
  cdn_frontdoor_profile_id =  azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "o1" {
  name                     = "${var.resource_group_location}-cluster"
  cdn_frontdoor_profile_id =  azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {
  }
}

resource "azurerm_service_plan" "asp1" {
  name                = "asp-${local.specifier}-1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_type = "Linux"
  sku_name = "P0v3"
} 

resource "azurerm_linux_web_app" "app1" {
  name                = "wa-${local.specifier}-1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp1.location
  service_plan_id     = azurerm_service_plan.asp1.id

  site_config {
    application_stack {
      docker_image_name = "tjsullivan1/simple-http-server:latest"
    }
  }
}

resource "azurerm_linux_web_app_slot" "slot" {
  name           = "release"
  app_service_id = azurerm_linux_web_app.app1.id

  site_config {
    application_stack {
      docker_image_name = "tjsullivan1/simple-http-server:latest"
    }
  }
}