#!/usr/bin/env bash
set -euo pipefail


# ===== EDIT THESE =====
ORG="tjsullivan1"
LOCATION="canadacentral"
SUBSCRIPTION_ID="<your-subscription-id>"
PLATFORM_RG="rg-platform-dev"


# ===== Generate unique names =====
RAND6() { openssl rand -hex 3; }
TFSTATE_SA="sttfstate$(RAND6)" # must be globally unique
TFSTATE_CONT="tfstate"
KEYVAULT_NAME="kv-dev-$(openssl rand -hex 2)"
ACR_NAME="acrdev$(RAND6)"
LOGWS="log-dev-$(openssl rand -hex 2)"
APP_NAME="gha-deploy"


# ===== Azure context =====
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)


# ===== Resource Group =====
az group create -n "$PLATFORM_RG" -l "$LOCATION" 1>/dev/null


# ===== tfstate storage =====
az storage account create -g "$PLATFORM_RG" -n "$TFSTATE_SA" -l "$LOCATION" --sku Standard_LRS --kind StorageV2 1>/dev/null
az storage container create --account-name "$TFSTATE_SA" -n "$TFSTATE_CONT" --auth-mode login 1>/dev/null


# ===== Key Vault =====
az keyvault create -g "$PLATFORM_RG" -n "$KEYVAULT_NAME" -l "$LOCATION" --enable-rbac-authorization true 1>/dev/null


# ===== ACR =====
az acr create -g "$PLATFORM_RG" -n "$ACR_NAME" --sku Basic 1>/dev/null


# ===== Log Analytics =====
az monitor log-analytics workspace create -g "$PLATFORM_RG" -n "$LOGWS" -l "$LOCATION" 1>/dev/null || true


# ===== App Registration (OIDC) =====
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)


# Subscription-level Reader (baseline). Project RGs will get Contributor, per-repo.
az role assignment create --assignee "$SP_ID" --role Reader --scope "/subscriptions/$SUBSCRIPTION_ID" 1>/dev/null || true
# ACR push (optional, helpful for CI builds)
az role assignment create --assignee "$SP_ID" --role AcrPush --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$PLATFORM_RG/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME" 1>/dev/null || true


# ===== GitHub org-level variables =====
# (No secrets – we use OIDC)
command -v gh >/dev/null 2>&1 || { echo "gh CLI required"; exit 1; }


echo "Setting GitHub org variables on $ORG ..."


gh variable set AZURE_TENANT_ID --org "$ORG" --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --org "$ORG" --body "$SUBSCRIPTION_ID"
gh variable set AZURE_CLIENT_ID --org "$ORG" --body "$APP_ID"
gh variable set TFSTATE_ACCOUNT --org "$ORG" --body "$TFSTATE_SA"
gh variable set TFSTATE_CONTAINER --org "$ORG" --body "$TFSTATE_CONT"
gh variable set TFSTATE_RG --org "$ORG" --body "$PLATFORM_RG"
gh variable set ACR_NAME --org "$ORG" --body "$ACR_NAME"
gh variable set KEYVAULT_NAME --org "$ORG" --body "$KEYVAULT_NAME"
gh variable set AZ_REGION --org "$ORG" --body "$LOCATION"


echo "\nBootstrap complete. Save these for reference:"
echo "TENANT_ID=$TENANT_ID"
echo "SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo "APP_ID(AZURE_CLIENT_ID)=$APP_ID"
echo "PLATFORM_RG=$PLATFORM_RG | TFSTATE: $TFSTATE_SA/$TFSTATE_CONT | ACR=$ACR_NAME | KV=$KEYVAULT_NAME"