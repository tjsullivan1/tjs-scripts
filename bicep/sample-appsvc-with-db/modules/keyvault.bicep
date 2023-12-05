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
