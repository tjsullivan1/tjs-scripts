<#
Adapted from:
https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-collector-api#powershell-sample
#>
[CmdletBinding()]
param(
    # Replace with your Workspace ID
    $WorkspaceId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  

    # Replace with your Primary Key
    $SharedKey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    
    # Specify the name of the record type that you'll be creating
    $LogType = "ExpiringResourceGroups",

    $Cloud =  "AzureCloud" # "AzureUSGovernment" should be used for US Gov
)

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = ""

# Create the function to create the authorization signature
Function Build-Signature ($WorkspaceId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $WorkspaceId,$encodedHash
    return $authorization
}


# Create the function to create and post the request
Function Post-LogAnalyticsData($WorkspaceId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -WorkspaceId $WorkspaceId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    
    if ($cloud -eq "AzureUSGovernment") {
        $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.us" + $resource + "?api-version=2016-04-01"
    } else {
        $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    }
    write-output $uri
    write-output $WorkspaceId

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode

}

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$query = "resourcecontainers `
| extend tag_expiration = tags.expireOn `
| extend expiration = todatetime(tag_expiration) `
| extend owner = tags.businessowner `
| where expiration < now(+7d) `
| project resourceGroup, expiration, owner"

$expResources= Search-AzGraph -Query $query
write-output $expResources

$json = convertto-json $expResources

# Submit the data to the API endpoint
Post-LogAnalyticsData -WorkspaceId $WorkspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType

