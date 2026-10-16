function Get-TransactionSeries {
    <#
    .SYNOPSIS
    Validates and enumerates a Transactions metric response.
    #>
    param([hashtable]$Response)
    $metrics = @($Response['value'] | Where-Object { $_['name'] -and $_['name']['value'] -eq 'Transactions' })
    if ($metrics.Count -ne 1) { throw 'Response must contain exactly one Transactions metric.' }
    $metric = $metrics[0]
    if ($metric['errorCode'] -and $metric['errorCode'] -ne 'Success') {
        throw "Transactions error $($metric['errorCode']): $($metric['errorMessage'])"
    }
    if ($metric['unit'] -ne 'Count') { throw 'Transactions metric did not return Count units.' }
    if (-not $metric.ContainsKey('timeseries')) { throw 'Missing Transactions timeseries field.' }
    foreach ($series in $metric['timeseries']) { $series }
}
