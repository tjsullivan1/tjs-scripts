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
  length           = 4
}

resource "azurerm_resource_group" "tjs" {
  name = "rg-" + var.disambiguation + resource.random_string.suffix
}

module "sa1" {
  count = 2
  source = "../modules/storage_account"

  resource_group_name = azurerm_resource_group.tjs.name
  storage_account_name = "sa" + var.disambiguation + resource.random_string.suffix + count.index

}