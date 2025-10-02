variable "location" {
  description = "The Azure region where the resource will be deployed."
  type        = string
}

variable "ai_foundry_name" {
  description = "The name of the AI Foundry resource."
  type        = string
  default     = "aifoundry"
}

variable "sku_name" {
  description = "The SKU name for the AI Foundry service."
  type        = string
  default     = "S0"
}

variable "disable_local_auth" {
  description = "Whether to disable local authentication (API key). Set to true for Entra ID only."
  type        = bool
  default     = false
}

variable "gpt_deployment_name" {
  description = "The name of the GPT deployment."
  type        = string
  default     = "gpt-4o"
}

variable "gpt_model_name" {
  description = "The name of the GPT model to deploy."
  type        = string
  default     = "gpt-4o"
}

variable "gpt_model_version" {
  description = "The version of the GPT model to deploy."
  type        = string
  default     = "2024-11-20"
}

variable "gpt_sku_name" {
  description = "The SKU name for the GPT deployment."
  type        = string
  default     = "GlobalStandard"
}

variable "gpt_capacity" {
  description = "The capacity for the GPT deployment."
  type        = number
  default     = 1
}

variable "project_name" {
  description = "The name of the AI Foundry project."
  type        = string
  default     = "project"
}

variable "project_display_name" {
  description = "The display name of the AI Foundry project."
  type        = string
  default     = "AI Foundry Project"
}

variable "project_description" {
  description = "The description of the AI Foundry project."
  type        = string
  default     = "AI Foundry project for machine learning workloads"
}
