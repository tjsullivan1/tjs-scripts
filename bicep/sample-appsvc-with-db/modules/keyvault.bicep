param keyVaultName string
param location string = 'West US'

param sqlAdminLogin string
@secure()
param sqlPasssword string
param sqlDatabaseName string

var sqlConnectionString = 'Server=tcp:${sqlDatabaseName}.database.windows.net,1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlPasssword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'


resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
  }
}

resource sqlConnectionStringResource 'Microsoft.KeyVault/vaults/secrets@2022-11-01' = {
  name: '${keyVaultName}/sqlConnectionString'
  properties: {
    value: sqlConnectionString
  }
}

output keyVaultId string = keyVault.id

$token = Get-AzAccessToken | select -ExpandProperty Token
$authHeader = @{
  'Content-Type'='application/json'
  'Authorization'='Bearer ' + $token
}
$subId = "f33f4d2a-99ac-47ab-8142-a5f6f768020f"
echo $authHeader
$resourceGroup = "rg-devbox-testing"
$deploymentName = 'vnet-devbox'
$uri = 'https://management.azure.com/subscriptions/' + $subId + '/resourcegroups/' + $resourceGroup + '/providers/Microsoft.Resources/deployments/' + $deploymentName + '?api-version=2021-04-01'
echo $uri

invoke-restmethod -method GET -uri $uri -headers $authHeader

https://management.azure.com/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}/providers/Microsoft.Resources/deployments/?api-version={api-version}


subId="9dc23aa2-5815-46a5-9303-9aa5847aaf13"
location="eastus"
url="https://management.azure.com/subscriptions/$subId/providers/Microsoft.CognitiveServices/locations/$location/usages?api-version=2023-05-01"


az login --service-principal -u ca1b836f-99ca-495d-a3b5-a321e849bdec -p pvb8Q~2wB~td5kVc1SEv7TWfKRDRb2.JqXr-9chC --tenant 012c6d21-cad3-4e61-98dd-2bc660a112b8
