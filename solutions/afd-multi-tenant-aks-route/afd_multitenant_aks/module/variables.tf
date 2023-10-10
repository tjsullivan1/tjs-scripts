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

variable "indicator_suffix" {
  type        = string
  default     = "1"
  description = "Suffix of the indicator that's combined with a random ID so name is unique in your Azure subscription."
}

variable "domain_name" {
  type        = string
  description = "The domain name to use for the DNS zone."
}

variable "zone_resource_group" {
  type        = string
  description = "The resource group where the DNS zone exists"
}

variable "ingress_ip" {
  type        = string
  description = "The IP address of the ingress controller"
}

variable "ingress_name" {
  type        = string
  description = "The name of the ingress controller for DNS purposes"
}

variable "secondary_ingress_name" {
  type        = string
  description = "The name of the ingress controller for DNS purposes"
}

variable "custom_subdomain_names" {
  type        = list(string)
  description = "List of different subdomains to use for ASK endpoints"
}