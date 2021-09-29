terraform {
  required_version = "~> 1.0.0"
  required_providers {
    azurerm = {
      source  = "registry.terraform.io/hashicorp/azurerm"
      version = "> 2.72.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = false
  features {}
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}



resource "azurerm_resource_group" "monitor" {
  name     = "rg-monitoring-resources"
  location = "East US"
}

resource "azurerm_monitor_action_group" "mag" {
  name                = "CriticalAlertsAction"
  resource_group_name = azurerm_resource_group.monitor.name
  short_name          = "p0action"


  email_receiver {
    name                    = "TJS"
    email_address           = "tisulliv@microosft.com"
    use_common_alert_schema = true
  }

}