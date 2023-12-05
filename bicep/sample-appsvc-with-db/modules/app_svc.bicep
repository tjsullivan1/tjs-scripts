param appServicePlan string
param appName string
param appServiceSku string = 'Y1'
param location string = 'West US'
param keyVaultName string
param keyVaultSecretName string

var keyVaultSecretReference = '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${keyVaultSecretName})'

// Create an App Service Plan
resource sampleAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlan
  location: location
  sku: {
    name: appServiceSku
  }

  properties: {
    reserved: true
  }
}


resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: sampleAppPlan.id
    
    siteConfig: {
      appSettings: [
        {
          name: 'SqlDbConnectionString'
          value: keyVaultSecretReference
        }
        {
          name: 'Setting2'
          value: 'Value2'
        }
      ]
    }
  }
}

output appServiceName string = appService.name
output appManagedIdentity string = appService.identity.principalId
