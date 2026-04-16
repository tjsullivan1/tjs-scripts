# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID for the deployment."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "name_prefix" {
  description = "Short prefix used to generate unique resource names."
  type        = string
  default     = "aigateway"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "name_prefix must be 3-12 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project = "ai-gateway-billing-sample"
  }
}

# -----------------------------------------------------------------------------
# AI Foundry
# -----------------------------------------------------------------------------

variable "foundry_sku" {
  description = "SKU for the AI Foundry (Cognitive Services) account."
  type        = string
  default     = "S0"
}

variable "chat_model_name" {
  description = "Model name for the chat deployment."
  type        = string
  default     = "gpt-4.1"
}

variable "chat_model_version" {
  description = "Model version for the chat deployment."
  type        = string
  default     = "2025-04-14"
}

variable "chat_model_sku" {
  description = "SKU name for the chat model deployment."
  type        = string
  default     = "GlobalStandard"
}

variable "chat_model_capacity" {
  description = "Capacity (in thousands of tokens per minute) for the chat model."
  type        = number
  default     = 50
}

variable "additional_chat_models" {
  description = "Additional chat model deployments. Each entry creates a new deployment in AI Foundry."
  type = map(object({
    version  = string
    sku      = optional(string, "GlobalStandard")
    capacity = optional(number, 50)
  }))
  default = {
    "gpt-4o-mini" = {
      version = "2024-07-18"
    }
    "gpt-5.1-chat" = {
      version = "2025-06-01"
    }
  }
}

variable "embeddings_model_name" {
  description = "Model name for the embeddings deployment (used by semantic cache)."
  type        = string
  default     = "text-embedding-3-small"
}

variable "embeddings_model_version" {
  description = "Model version for the embeddings deployment."
  type        = string
  default     = "1"
}

variable "embeddings_model_sku" {
  description = "SKU name for the embeddings model deployment."
  type        = string
  default     = "GlobalStandard"
}

variable "embeddings_model_capacity" {
  description = "Capacity for the embeddings model deployment."
  type        = number
  default     = 120
}

# -----------------------------------------------------------------------------
# API Management
# -----------------------------------------------------------------------------

variable "apim_sku" {
  description = "APIM SKU tier."
  type        = string
  default     = "Developer"

  validation {
    condition     = contains(["Developer", "Basicv2", "StandardV2"], var.apim_sku)
    error_message = "apim_sku must be Developer, Basicv2, or StandardV2."
  }
}

variable "apim_publisher_name" {
  description = "Publisher name shown in the APIM developer portal."
  type        = string
  default     = "AI Gateway Demo"
}

variable "apim_publisher_email" {
  description = "Publisher email for APIM notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.apim_publisher_email))
    error_message = "Must be a valid email address."
  }
}

# -----------------------------------------------------------------------------
# Token Limits (per product)
# -----------------------------------------------------------------------------

variable "standard_tokens_per_minute" {
  description = "Token-per-minute limit for the AI-Standard product."
  type        = number
  default     = 1000
}

variable "standard_token_quota" {
  description = "Hourly token quota for the AI-Standard product."
  type        = number
  default     = 5000
}

variable "premium_tokens_per_minute" {
  description = "Token-per-minute limit for the AI-Premium product."
  type        = number
  default     = 50000
}

variable "premium_token_quota" {
  description = "Hourly token quota for the AI-Premium product."
  type        = number
  default     = 250000
}

# -----------------------------------------------------------------------------
# Semantic Cache
# -----------------------------------------------------------------------------

variable "cache_score_threshold" {
  description = "Similarity score threshold for semantic cache hits (0.0 to 1.0)."
  type        = number
  default     = 0.05
}

variable "cache_duration_seconds" {
  description = "Duration in seconds to keep responses in semantic cache."
  type        = number
  default     = 600
}

# -----------------------------------------------------------------------------
# Billing / Metrics
# -----------------------------------------------------------------------------

variable "metric_namespace" {
  description = "Custom metric namespace for llm-emit-token-metric."
  type        = string
  default     = "AIGateway"
}

variable "cost_per_1k_prompt_tokens" {
  description = "Estimated cost per 1K prompt tokens (for KQL cost projections)."
  type        = number
  default     = 0.01
}

variable "cost_per_1k_completion_tokens" {
  description = "Estimated cost per 1K completion tokens (for KQL cost projections)."
  type        = number
  default     = 0.03
}

# -----------------------------------------------------------------------------
# Key Vault (optional)
# -----------------------------------------------------------------------------

variable "enable_key_vault" {
  description = "Deploy a Key Vault and store consumer credentials as secrets."
  type        = bool
  default     = false
}

variable "key_vault_reader_object_ids" {
  description = "Additional Entra ID object IDs to grant Key Vault Secrets User role. Useful when the deployer differs from the person running tests."
  type        = list(string)
  default     = []
}
