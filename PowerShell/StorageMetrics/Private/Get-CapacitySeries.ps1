function Get-CapacitySeries {
    <#
    .SYNOPSIS
    Reads a capacity metric using an explicit saved context and retry limit.
    #>
    param([string]$Path, [string]$Metric, [object]$Context, [int]$MaxRetry)
    $response = Invoke-StorageArmGet -Path $Path -Context $Context -MaxRetry $MaxRetry
    $body = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($body -isnot [hashtable] -or $body['interval'] -ne 'PT1H') {
        throw "$Metric must return PT1H intervals."
    }
    $metrics = @($body['value'] | Where-Object { $_['name'] -and $_['name']['value'] -eq $Metric })
    if ($metrics.Count -ne 1) { throw "Response must contain exactly one $Metric metric." }
    $value = $metrics[0]
    if ($value['errorCode'] -and $value['errorCode'] -ne 'Success') {
        throw "$Metric error $($value['errorCode']): $($value['errorMessage'])"
    }
    if ($value['unit'] -ne 'Bytes' -or -not $value.ContainsKey('timeseries')) {
        throw "$Metric requires Bytes units and a timeseries field."
    }
    foreach ($series in $value['timeseries']) { $series }
}
