terraform {
  required_version = "> 1.0.0"
  required_providers {
    azurerm = {
      source  = "registry.terraform.io/hashicorp/azurerm"
      version = "> 2.72.0"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~> 3.1.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = false
  features {}
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

resource "azurerm_resource_group" "tjs" {
  name = "rg-${var.disambiguation}-${random_string.suffix.result}"
  location = var.location
}

module "sa1" {
  count = 2
  source = "../modules/storage_account"

  resource_group_name = azurerm_resource_group.tjs.name
  storage_account_name = "sa${lower(var.disambiguation)}${random_string.suffix.result}${count.index}"

}