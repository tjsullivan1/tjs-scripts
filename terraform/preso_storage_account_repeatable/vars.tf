variable "disambiguation" {
    type = string
    description = "Provides an indication of what this particular storage account is for."
}

variable "location" {
  type = string
  description = "Azure Region"
  default = "eastus"
}
