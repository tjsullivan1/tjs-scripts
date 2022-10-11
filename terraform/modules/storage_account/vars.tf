variable "location" {
  type = string
  description = "Azure Region"
  default = "eastus"
}

variable "storage_account_name" {
  type = string
  description = "a name for the storage account"
}

variable "resource_group_name" {
  type = string
  description = "The name for the resource group."
}