[CmdletBinding()]
param (
    $imageResourceGroup,
    $imageTemplateName,
    [switch]$SelectRunState,
    [switch]$SelectDuration
)

begin {
    $currentAzureContext = Get-AzContext

    ### Step 2: Get instance profile
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
        
    Write-Verbose ("Tenant: {0}" -f  $currentAzureContext.Subscription.Name)
    
    ### Step 4: Get token  
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $accessToken=$token.AccessToken
    
    $managementEp = $currentAzureContext.Environment.ResourceManagerUrl

}

process {
    $urlBuildStatus = [System.String]::Format("{0}subscriptions/{1}/resourceGroups/$imageResourceGroup/providers/Microsoft.VirtualMachineImages/imageTemplates/{2}?api-version=2019-05-01-preview", $managementEp, $currentAzureContext.Subscription.Id,$imageTemplateName)
    $buildStatusResult = Invoke-WebRequest -Method GET  -Uri $urlBuildStatus -UseBasicParsing -Headers  @{"Authorization"= ("Bearer " + $accessToken)} -ContentType application/json 
    $buildJsonStatus =$buildStatusResult.Content
    $buildStatus = $buildJsonStatus
    
    if ($SelectRunState) {
        $buildStatus = $buildJsonStatus | convertfrom-json | select -ExpandProperty Properties | select -ExpandProperty lastRunStatus | select -ExpandProperty runstate
    }
    
    if ($SelectDuration) {
        [datetime]$nullTime = "Monday, January 1, 0001 12:00:00 AM"
        $LastRunStatus = $buildJsonStatus |convertfrom-json | select -ExpandProperty Properties | select -ExpandProperty lastRunStatus
        if ($lastRunStatus.endTime -eq $nullTime) {
            $ct = get-date
            $duration = $ct - [datetime]$lastRunStatus.startTime
            $buildStatus = $duration.TotalMinutes
        } else {
            $duration = [datetime]$lastRunStatus.endTime - [datetime]$lastRunStatus.startTime
            $buildStatus = $duration.TotalMinutes
        }
    }

    $buildStatus
    
}

end {
    
}
