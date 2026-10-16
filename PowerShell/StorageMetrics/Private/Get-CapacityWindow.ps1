function Get-CapacityWindow {
    <#
    .SYNOPSIS
    Reconciles hourly Blob capacity splits and collects independent HNS index samples.
    #>
    param([datetimeoffset]$First, [datetimeoffset]$Last,
        [object]$Template, [object]$Context, [int]$MaxRetry)
    $format = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $span = [uri]::EscapeDataString(
        "$($First.ToString($format, [cultureinfo]::InvariantCulture))/$($Last.ToString($format, [cultureinfo]::InvariantCulture))"
    )
    $path = "$($Template.MetricResourceId)/providers/Microsoft.Insights/metrics" +
        '?api-version=2023-10-01&metricnamespace=Microsoft.Storage%2FstorageAccounts%2FblobServices' +
        "&aggregation=Average&interval=PT1H&timespan=$span&AutoAdjustTimegrain=false&ValidateDimensions=true"
    $split = @(Get-CapacitySeries -Path (
        $path + '&metricnames=BlobCapacity&top=10000&%24filter=' + [uri]::EscapeDataString("Tier eq '*' and BlobType eq '*'")
    ) -Metric 'BlobCapacity' -Context $Context -MaxRetry $MaxRetry)
    if ($split.Count -ge 10000) {
        return @{
            NeedsSplit = $true
            Message = 'Capacity series reached top=10000; completeness cannot be verified.'
            Groups = @{}
            ReconciliationMissing = $false
        }
    }
    $totalSeries = @(Get-CapacitySeries -Path ($path + '&metricnames=BlobCapacity') -Metric 'BlobCapacity' -Context $Context -MaxRetry $MaxRetry)
    if ($totalSeries.Count -gt 1) { throw 'Unsplit BlobCapacity returned multiple series.' }
    $totalPoints = @{}
    if ($totalSeries.Count) { $totalPoints = Get-CapacityPoints $totalSeries[0] $First $Last }
    $chunkGroups = @{}
    foreach ($series in $split) {
        $dimensions = @{}
        foreach ($metadata in $series['metadatavalues']) {
            $dimension = $metadata['name']['value']
            if ($dimensions.ContainsKey($dimension)) { throw 'Duplicate capacity dimension.' }
            $dimensions[$dimension] = $metadata['value']
        }
        if (-not $dimensions.ContainsKey('Tier') -or -not $dimensions.ContainsKey('BlobType')) {
            throw 'BlobCapacity split is missing Tier or BlobType.'
        }
        $key = ConvertTo-Json -InputObject @($dimensions['Tier'], $dimensions['BlobType']) -Compress
        if ($chunkGroups.ContainsKey($key)) { throw 'Duplicate capacity dimension series.' }
        $chunkGroups[$key] = @{
            Type = 'Capacity'; Metric = 'BlobCapacity'
            Tier = $dimensions['Tier']; BlobType = $dimensions['BlobType']
            Points = (Get-CapacityPoints $series $First $Last)
        }
    }
    $reconciliationMissing = $false
    for ($time = $First; $time -lt $Last; $time = $time.AddHours(1)) {
        $key = $time.ToString('o')
        $sum = [decimal]0
        $missing = -not $chunkGroups.Count -or $null -eq $totalPoints[$key]
        foreach ($group in $chunkGroups.Values) {
            if ($null -eq $group.Points[$key]) { $missing = $true }
            else { $sum += $group.Points[$key] }
        }
        if ($missing) { $reconciliationMissing = $true }
        elseif ([math]::Abs($sum - $totalPoints[$key]) -gt [math]::Max([decimal]1, $totalPoints[$key] * [decimal]0.000000001)) {
            return @{
                NeedsSplit = $true
                Message = 'Split BlobCapacity does not match unsplit hourly capacity.'
                Groups = @{}
                ReconciliationMissing = $false
            }
        }
    }
    $chunkGroups['AccountTotal'] = @{
        Type = 'CapacityAccountTotal'; Metric = 'BlobCapacity'; Tier = $null
        BlobType = $null; Points = $totalPoints
    }
    if ($Template.IsHnsEnabled -eq $true) {
        $indexSeries = @(Get-CapacitySeries -Path ($path + '&metricnames=IndexCapacity') -Metric 'IndexCapacity' -Context $Context -MaxRetry $MaxRetry)
        if ($indexSeries.Count -gt 1) { throw 'IndexCapacity returned multiple series.' }
        $indexPoints = @{}
        if ($indexSeries.Count) { $indexPoints = Get-CapacityPoints $indexSeries[0] $First $Last }
        $chunkGroups['Index'] = @{
            Type = 'IndexCapacity'; Metric = 'IndexCapacity'; Tier = $null
            BlobType = $null; Points = $indexPoints
        }
    }
    return @{
        NeedsSplit = $false
        Message = $null
        Groups = $chunkGroups
        ReconciliationMissing = $reconciliationMissing
    }
}
