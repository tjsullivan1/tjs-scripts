<#
Gets all resources in a resource group and enables diagnostics.
#>
[cmdletbinding()]
param(
    [Parameter(mandatory=$true)]
    [string] $StorageAccountId,

    [Parameter(mandatory=$true)]
    [string] $LogAnalyticsWorkspaceId,

    [Parameter(mandatory=$true)]
    [string] $ResourceGroupName
)

Get-AzResource -ResourceGroupName $ResourceGroupName | % { 
    $id =  $_.resourceid
    Set-AzDiagnosticSetting -ResourceId $id -StorageAccountId $StorageAccountId -WorkspaceId $LogAnalyticsWorkspaceId -RetentionInDays 90 -RetentionEnabled $true -Enabled $true
}
