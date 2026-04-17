terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.68"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.9"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # Google provider for Gemini API resources (API key, enabled services).
    # Auth via `gcloud auth application-default login` — same pattern as az login.
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}

provider "azuread" {}

provider "google" {
  project               = var.enable_gemini ? var.gcp_project_id : null
  billing_project       = var.enable_gemini ? var.gcp_project_id : null
  user_project_override = var.enable_gemini
}
