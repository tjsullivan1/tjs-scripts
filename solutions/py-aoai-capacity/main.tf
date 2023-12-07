terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

data "azurerm_subscription" "current" {
}

variable "location" {
  type = string
  default = "eastus"
}

variable "model_name" {
  type = string
  default = "OpenAI.Standard.text-davinci-003"
}

data "external" "test" {
  program = ["python", "./main.py", "--model-name",  var.model_name, "--location", var.location, "--subscription-id", data.azurerm_subscription.current.subscription_id ]
}

locals {
  capacity = data.external.test.result
}

output "test" {
  value = local.capacity
}

output "remaining_capacity" {
  value = local.capacity.remaining
}