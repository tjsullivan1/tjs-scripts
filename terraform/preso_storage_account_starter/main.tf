terraform {
  required_version = "~> 1.0.0"
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
  name     = "rg-${var.disambiguation}-${random_string.suffix.result}"
  location = var.location

  # Uncomment for Demo on Challenges
  # lifecycle {
  #   ignore_changes = [ tags, ]
  # }
}

resource "azurerm_storage_account" "tjs" {
  name                     = "sa${lower(var.disambiguation)}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tjs.name
  location                 = azurerm_resource_group.tjs.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  network_rules {
    default_action = "Deny"
    ip_rules       = ["73.65.80.95"]
  }

  tags = {
    environment = "staging"
  }
}