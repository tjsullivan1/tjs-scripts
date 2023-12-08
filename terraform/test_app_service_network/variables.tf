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

variable "vnet_resource_group" {
  type = string
  description = "Name of the resource group that contains the virtual network."
}

variable "vnet_name" {
  type = string
  description = "Name of the virtual network that already exists."
}