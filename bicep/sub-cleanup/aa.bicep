param automation_account_name string 
param location string = resourceGroup().location

resource myaa 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: automation_account_name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    sku: {
      name: 'Basic'
    }
  }
}


// Define the modules for the AA
resource module_Az_Accounts 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Accounts'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Advisor 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Advisor'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Aks 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Aks'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_AnalysisServices 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.AnalysisServices'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ApiManagement 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ApiManagement'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_AppConfiguration 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.AppConfiguration'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ApplicationInsights 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ApplicationInsights'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Automation 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Automation'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Batch 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Batch'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Billing 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Billing'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Cdn 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Cdn'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_CognitiveServices 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.CognitiveServices'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Compute 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Compute'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ContainerInstance 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ContainerInstance'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ContainerRegistry 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ContainerRegistry'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_CosmosDB 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.CosmosDB'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DataBoxEdge 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DataBoxEdge'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Databricks 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Databricks'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DataFactory 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DataFactory'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DataLakeAnalytics 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DataLakeAnalytics'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DataLakeStore 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DataLakeStore'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DataShare 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DataShare'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DeploymentManager 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DeploymentManager'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DesktopVirtualization 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DesktopVirtualization'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_DevTestLabs 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.DevTestLabs'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Dns 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Dns'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_EventGrid 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.EventGrid'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_EventHub 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.EventHub'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_FrontDoor 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.FrontDoor'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Functions 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Functions'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_HDInsight 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.HDInsight'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_HealthcareApis 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.HealthcareApis'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_IotHub 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.IotHub'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_KeyVault 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.KeyVault'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Kusto 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Kusto'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_LogicApp 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.LogicApp'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_MachineLearning 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.MachineLearning'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Maintenance 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Maintenance'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ManagedServices 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ManagedServices'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_MarketplaceOrdering 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.MarketplaceOrdering'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Media 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Media'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Migrate 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Migrate'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Monitor 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Monitor'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Network 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Network'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_NotificationHubs 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.NotificationHubs'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_OperationalInsights 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.OperationalInsights'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_PolicyInsights 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.PolicyInsights'
  properties: {
    contentLink: {
    }
  }
}

resource module_Az_PowerBIEmbedded 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.PowerBIEmbedded'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_PrivateDns 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.PrivateDns'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_RecoveryServices 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.RecoveryServices'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_RedisCache 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.RedisCache'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_RedisEnterpriseCache 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.RedisEnterpriseCache'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Relay 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Relay'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ResourceGraph 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ResourceGraph'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Resources 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Resources'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ServiceBus 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ServiceBus'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_ServiceFabric 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.ServiceFabric'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_SignalR 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.SignalR'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Sql 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Sql'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_SqlVirtualMachine 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.SqlVirtualMachine'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Storage 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Storage'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_StorageSync 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.StorageSync'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_StreamAnalytics 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.StreamAnalytics'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Support 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Support'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_TrafficManager 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.TrafficManager'
  properties: {
    contentLink: {
    }
  }
}
resource module_Az_Websites 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az.Websites'
  properties: {
    contentLink: {
    }
  }
}
resource Microsoft_Automation_automationAccounts_modules_module_Azure 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Azure'
  properties: {
    contentLink: {
    }
  }
}
