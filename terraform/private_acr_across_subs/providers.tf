# providers.tf
terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}
provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias = "secondary"

  subscription_id = var.secondary_subscription_id
  client_id       = var.secondary_subscription_client_id
  client_secret   = var.secondary_subscription_client_secret
  tenant_id       = var.secondary_subscription_tenant_id

  features {}
}