function Get-TransactionChunkRecords {
    <#
    .SYNOPSIS
    Buffers one classified request window after split/total reconciliation.
    #>
    param(
        [datetimeoffset]$WindowStart,
        [datetimeoffset]$WindowEnd,
        [object]$Context,
        [hashtable]$AccountMap,
        [bool]$SupportsLake,
        [hashtable]$RecordParameters, [hashtable]$LakeMap,
        [string[]]$Categories, [bool]$CollectDetail, [string]$SummaryPeriod,
        [int]$MaxRetry
    )
    $id = $RecordParameters.Id
    $chunkStart = $WindowStart
    $chunkEnd = $WindowEnd
    $utcFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $timespan = [uri]::EscapeDataString(
        "$($chunkStart.ToString($utcFormat, [cultureinfo]::InvariantCulture))/$($chunkEnd.ToString($utcFormat, [cultureinfo]::InvariantCulture))"
    )
    $path = "$id/blobServices/default/providers/Microsoft.Insights/metrics" +
        "?api-version=2023-10-01&metricnamespace=Microsoft.Storage%2FstorageAccounts%2FblobServices" +
        "&metricnames=Transactions&aggregation=Total&interval=FULL&timespan=$timespan" +
        '&AutoAdjustTimegrain=false&ValidateDimensions=true'
    $filter = "ApiName eq '*' and ResponseType eq '*' and Tier eq '*' and " +
        "GeoType eq '*' and Authentication eq '*' and TransactionType eq '*'"
    $splitResponse = Invoke-StorageMetricRequest -Path (
        $path + '&top=10000&%24filter=' + [uri]::EscapeDataString($filter)
    ) -Context $Context -MaxRetry $MaxRetry
    $split = @(Get-TransactionSeries -Response $splitResponse)
    if ($split.Count -ge 10000) {
        return @{
            NeedsSplit = $true
            Message = 'Split series reached top=10000; completeness cannot be verified.'
            Records = @()
        }
    }
    $totalResponse = Invoke-StorageMetricRequest -Path $path -Context $Context -MaxRetry $MaxRetry
    $totalSeries = @(Get-TransactionSeries -Response $totalResponse)
    if ($totalSeries.Count -gt 1) { throw 'Unsplit query unexpectedly returned multiple series.' }
    $total = $null
    if ($totalSeries.Count -eq 1) {
        $total = Get-SeriesCount -Series $totalSeries[0]
    } elseif ($split.Count -eq 0 -and $totalResponse['value'][0]['errorCode'] -eq 'Success' -and
        $splitResponse['value'][0]['errorCode'] -eq 'Success') {
        $total = [decimal]0
    }
    $missing = $null -eq $total
    $splitSum = [decimal]0
    $details = [System.Collections.Generic.List[object]]::new()
    $keys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $sums = @{}
    foreach ($category in $categories) { $sums[$category] = [decimal]0 }
    foreach ($series in $split) {
        $dimensions = @{}
        foreach ($metadata in $series['metadatavalues']) {
            $dimensions[$metadata['name']['value']] = $metadata['value']
        }
        foreach ($dimension in @('ApiName', 'ResponseType', 'Tier', 'GeoType', 'Authentication', 'TransactionType')) {
            if (-not $dimensions.ContainsKey($dimension)) {
                throw "Split series is missing dimension $dimension."
            }
        }
        $key = @($dimensions['ApiName'], $dimensions['ResponseType'], $dimensions['Tier'],
            $dimensions['GeoType'], $dimensions['Authentication'], $dimensions['TransactionType']) |
            ConvertTo-Json -Compress
        if (-not $keys.Add($key)) { throw 'Duplicate split dimension series.' }
        $count = Get-SeriesCount -Series $series
        if ($null -eq $count) { $missing = $true } else { $splitSum += $count }
        $api = $dimensions['ApiName']
        $category = 'Unmapped'
        $mappingStatus = 'UnknownApi'
        if ($null -eq $AccountMap) {
            $mappingStatus = 'UnsupportedAccount'
        } elseif ($api -eq 'SetBlobTier') {
            $mappingStatus = 'AmbiguousTierChangeOrBatch'
        } elseif ($SupportsLake -and $lakeMap.ContainsKey($api)) {
            $category = $lakeMap[$api]
            $mappingStatus = 'Documented'
        } elseif ($AccountMap.ContainsKey($api)) {
            $category = $AccountMap[$api]
            $mappingStatus = 'Documented'
        }
        if ($category -eq 'Free') { $mappingStatus = 'DocumentedFree' }
        if ($null -ne $count) { $sums[$category] += $count }
        $details.Add(@{ Category = $category; Count = $count; Dimensions = $dimensions; MappingStatus = $mappingStatus })
    }
    if (-not $missing -and $splitSum -ne $total) {
        return @{
            NeedsSplit = $true
            Message = "Split count $splitSum does not match unsplit count $total."
            Records = @()
        }
    }
    $completeness = 'Reconciled'
    $status = 'Observed'
    if ($missing) {
        $completeness = 'UnverifiableMissingData'
        $status = 'MissingData'
        Write-Warning "$id [$chunkStart, $chunkEnd): missing Totals; category summaries are null."
    }
    $chunkRecords = [System.Collections.Generic.List[object]]::new()
    $chunkRecords.Add((New-TransactionRecord @RecordParameters -ChunkStart $chunkStart -ChunkEnd $chunkEnd -SummaryPeriod $SummaryPeriod -Type 'AccountTotal' -Count $total -Status $(
        if ($null -eq $total) { 'MissingData' } else { 'Observed' }
    ) -Completeness $completeness))
    foreach ($category in $categories) {
        $count = $null
        if (-not $missing) { $count = $sums[$category] }
        $chunkRecords.Add((New-TransactionRecord @RecordParameters -ChunkStart $chunkStart -ChunkEnd $chunkEnd -SummaryPeriod $SummaryPeriod -Type 'Summary' -Category $category -Count $count `
            -Status $status -Completeness $completeness))
    }
    if ($collectDetail) {
        foreach ($detail in $details) {
            $chunkRecords.Add((New-TransactionRecord @RecordParameters -ChunkStart $chunkStart -ChunkEnd $chunkEnd -SummaryPeriod $SummaryPeriod -Type 'Detail' -Category $detail.Category -Count $detail.Count `
                -Status $(if ($null -eq $detail.Count) { 'MissingData' } else { 'Observed' }) `
                -Completeness $completeness -Dimensions $detail.Dimensions -MappingStatus $detail.MappingStatus))
        }
    }
    return @{ NeedsSplit = $false; Message = $null; Records = $chunkRecords.ToArray() }
}
