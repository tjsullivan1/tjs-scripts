[CmdletBinding()]
param (
    $StartTime = (Get-Date),
    $EndTime = ($startTime.AddHours(2.0)),
    $containerName = "packerlogs"
)

$sub = az account show --query id -o tsv

# Use the REST endpoint to get created time, PowerShell cmdlet does not show that.
$rgs = az rest --method get --url "https://management.azure.com/subscriptions/$sub/resourcegroups?api-version=2019-08-01&%24expand=createdTime" | ConvertFrom-Json | Select-Object -ExpandProperty value
$rg = $rgs | Where-Object Name -like IT* | Sort-Object -descending createdTime | Select-Object -First 1 -ExpandProperty Name

$context = (Get-AzStorageAccount -ResourceGroupName $rg).context
$blobName = Get-AzStorageBlob -Container $containerName -Context $context | Select-Object -ExpandProperty Name

$token = New-AzStorageBlobSASToken -Blob $blobName -Container $containerName -StartTime $StartTime -ExpiryTime $EndTime -Permission r -Context $context

$url = $context.BlobEndPoint + $containerName + "/" + $blobName + $token

write-output $url