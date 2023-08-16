# variables.tf
variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location for all resources."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

# define variables for the primary subscriptions including the service principal client ID and secret
variable "primary_subscription_client_id" {
  type        = string
  description = "Client ID of the service principal used to authenticate to the primary subscription."
}

variable "primary_subscription_client_secret" {
  type        = string
  description = "Client secret of the service principal used to authenticate to the primary subscription."
}

variable "primary_subscription_id" {
  type        = string
  description = "Subscription ID of the primary subscription."
}

variable "primary_subscription_tenant_id" {
  type        = string
  description = "Tenant ID of the primary subscription."
}

# define variables for the secondary subscriptions including the service principal client ID and secret
variable "secondary_subscription_client_id" {
  type        = string
  description = "Client ID of the service principal used to authenticate to the secondary subscription."
}

variable "secondary_subscription_client_secret" {
  type        = string
  description = "Client secret of the service principal used to authenticate to the secondary subscription."
}

variable "secondary_subscription_id" {
  type        = string
  description = "Subscription ID of the secondary subscription."
}

variable "secondary_subscription_tenant_id" {
  type        = string
  description = "Tenant ID of the secondary subscription."
}

