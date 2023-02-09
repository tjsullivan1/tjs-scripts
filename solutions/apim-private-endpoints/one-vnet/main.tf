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
  # lifecycle {
  #   ignore_changes = [ tags, ]
  # }
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