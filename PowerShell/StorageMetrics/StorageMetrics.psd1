@{
    RootModule = 'StorageMetrics.psm1'
    ModuleVersion = '1.0.0'
    GUID = '0b2da47a-390c-4a69-9ce5-e5bb2b60f916'
    Author = 'tjsullivan1'
    Description = 'Observed Azure Blob/ADLS workload metrics and partial public-rate redundancy estimates.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Get-AzStorageTransactionMetric', 'Get-AzStorageRedundancyCost')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    FormatsToProcess = @('StorageMetrics.format.ps1xml')
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'Storage', 'Metrics')
            ProjectUri = 'https://github.com/tjsullivan1/tjs-scripts'
        }
    }
}
