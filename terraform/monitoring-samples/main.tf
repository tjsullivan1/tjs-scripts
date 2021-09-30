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

resource "azurerm_monitor_metric_alert" "k8spods" {
  name                = "k8s-pod-restart-metricalert"
  resource_group_name = azurerm_resource_group.monitor.name
  scopes              = ["/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/rg-handsonk8s/providers/Microsoft.ContainerService/managedClusters/aks-tjs-7cpgzar4jatom"]
  description         = "Action will be triggered when restart count is greater than 0."

  criteria {
    metric_namespace = "Insights.Container/pods"
    metric_name      = "restartingContainerCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
    skip_metric_validation = true

    dimension {
      name     = "kubernetes namespace"
      operator = "Include"
      values   = ["*"]
    }

    
    dimension {
      name     = "controllerName"
      operator = "Include"
      values   = ["*"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.mag.id
  }
}