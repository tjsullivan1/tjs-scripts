param sqlServerName string = 'mySqlServer'
param sqlDatabaseName string = 'mySqlDatabase'
param location string = 'westus2'
@secure()
param adminLoginPassword string
param adminLogin string = 'tjsadmin'


resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminLoginPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDatabaseName 
  parent: sqlServer
  location: location
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 1073741824 // 1 GB
    sampleName: 'AdventureWorksLT'
  }
}
