variable "disambiguation" {
  type        = string
  description = "Provides an indication of what this particular storage account is for."

  validation {
    condition = length(var.disambiguation) < 15
    error_message = "Please reduce the length of your disambiguation string."
  }
}

variable "location" {
  type = string
  description = "Azure Region"
  default = "eastus"
}

variable "random_string" {
  type = string
  description = "a randomly generated string"
}

variable "resource_group_name" {
  type = string
  description = "The name for the resource group."
}