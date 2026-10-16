function Invoke-StorageMetricRequest {
    <#
    .SYNOPSIS
    Parses an ARM metric/account response as a JSON object.
    #>
    param([string]$Path, [object]$Context, [int]$MaxRetry)
    $response = Invoke-StorageArmGet -Path $Path -Context $Context -MaxRetry $MaxRetry
    $content = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($content -isnot [hashtable]) { throw 'Expected an ARM JSON object response.' }
    return $content
}
