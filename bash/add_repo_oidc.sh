#!/usr/bin/env bash
set -euo pipefail


if [[ $# -ne 1 ]]; then
echo "Usage: $0 <repo-name>"; exit 1
fi


REPO="$1"
ORG="tjsullivan1"
REPO_NAME="$ORG/$REPO"
LOCATION="canadacentral"
SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
PLATFORM_RG="rg-platform-dev"
APP_NAME="gha-deploy"


# Lookup existing app by display name
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
[[ -z "$APP_ID" ]] && { echo "App $APP_NAME not found. Run platform_bootstrap.sh first."; exit 1; }


# Project RG per repo
PROJECT_RG="rg-${REPO_NAME}-dev"
az group create -n "$PROJECT_RG" -l "$LOCATION" 1>/dev/null


# Assign Contributor at project RG
SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
az role assignment create --assignee "$SP_ID" --role Contributor --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$PROJECT_RG" 1>/dev/null || true


# Federated credential: environment:dev
az ad app federated-credential create --id "$APP_ID" --parameters "$(jq -cn --arg repo "$REPO_NAME" '{
name: ("github-"+$repo+"-env-dev"),
issuer: "https://token.actions.githubusercontent.com",
subject: ("repo:"+$org+"/"+$repo+":environment:dev"),
audiences: ["api://AzureADTokenExchange"]
}')"


# Federated credential: branch main
az ad app federated-credential create --id "$APP_ID" --parameters "$(jq -cn --arg repo "$REPO_NAME" '{
name: ("github-"+$repo+"-main"),
issuer: "https://token.actions.githubusercontent.com",
subject: ("repo:"+$org+"/"+$repo+":ref:refs/heads/main"),
audiences: ["api://AzureADTokenExchange"]
}')"


echo "Federated creds added and RG $PROJECT_RG prepared."
echo "Next: create repo $REPO_NAME (from template), push, and run workflows."
