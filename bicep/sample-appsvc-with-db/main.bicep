param location string = resourceGroup().location
param sqlAdminLogin string = 'tjsadmin'
param sqlPassword string 


module appModule './modules/app_svc.bicep' = {
  name: 'tjs-app-svc'
  
  params: {
    appName: 'tjs-app1'
    appServicePlan: 'tjs-app-svc-plan'
    appServiceSku: 'S1'
    keyVaultName: 'tjs-kv'
    keyVaultSecretName: 'sqlConnectionString'
    location: location
  }
}

module dbModule './modules/sql.bicep' = {
  name: 'tjs-db'

  params: {
    sqlServerName: 'tjs-db-svr'
    sqlDatabaseName: 'tjs-db'
    adminLogin: sqlAdminLogin
    adminLoginPassword: sqlPassword
    location: location
  }

}

module kvModule './modules/keyvault.bicep' = {
  name: 'tjs-kv'

  params: {
    keyVaultName: 'tjs-kv'
    sqlDatabaseName: 'tjs-db'
    sqlAdminLogin: sqlAdminLogin
    sqlPasssword: sqlPassword
    location: location
  }
}

@description('Specifies the role definition ID used in the role assignment.')
param roleDefinitionID string = '4633458b-17de-408a-b874-0445c86b69e6'


var roleAssignmentName= guid('appservice', roleDefinitionID, resourceGroup().id)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: appModule.outputs.appManagedIdentity
  }
}
