function Get-AzStorageTransactionMetric {
    <#
    .SYNOPSIS
    Groups observed Blob/ADLS requests into documented operation categories.
    .DESCRIPTION
    Uses Azure Monitor Transactions (Total) on blobServices/default, with existing
    Az contexts. Returns flat objects, not prices or exact billed operations.
    Split series are reconciled with an unsplit service total for each time chunk.
    Returns UTC calendar-month totals by default, including partial months.
    No storage keys, diagnostic settings, or Azure context changes are used.
    .PARAMETER ResourceId
    Explicit storage account ARM IDs, potentially from multiple subscriptions.
    Accepts strings through the pipeline. Duplicate IDs are collected only once.
    .PARAMETER StartTime
    Inclusive start with an explicit offset, aligned to a whole minute.
    .PARAMETER EndTime
    Exclusive end with an explicit offset, aligned to a whole minute.
    .PARAMETER ChunkHours
    Maximum query window size (1 to 744 hours). Defaults to 24. Windows are split
    adaptively when reconciliation fails or a series limit is reached.
    Does not change the monthly reporting period.
    .PARAMETER MaxRetry
    Maximum retries for transient ARM GET responses. Defaults to 4.
    .PARAMETER AllowRecentData
    Allows collection ending within the three-hour Azure Monitor ingestion window.
    .PARAMETER SummaryPeriod
    Month (default) combines verified chunks into UTC calendar-month records.
    Chunk preserves the individual query-window records for troubleshooting.
    .PARAMETER IncludeDetail
    Includes each API/response/tier/authentication/geo/transaction-type series.
    Filter RecordType before summing: Detail, Summary and AccountTotal overlap.
    .PARAMETER IncludeCapacity
    Adds hourly BlobCapacity samples rolled up by tier/blob type and IndexCapacity
    for HNS accounts. Requires whole-hour boundaries. Used capacity is not exact
    billable capacity; missing hours remain visible and are never filled as zero.
    .PARAMETER IncludeCurrentCapacity
    Adds the latest reconciled Blob capacity sample from the last 24 complete
    hours, plus HNS index capacity when available. This is a current snapshot,
    independent of StartTime/EndTime, not a monthly billable-capacity average.
    .PARAMETER IncludeCostComparison
    Adds actual billed usage comparisons for completed UTC months. Uses the
    Cost Details report API; unsupported billing offers can supply CSV instead.
    .PARAMETER CostReportTimeoutMinutes
    Maximum Cost Details report polling time in minutes (1 to 60). Defaults to 10.
    .PARAMETER IncludeCostDetail
    Preserves each matched daily billing row in additional CostDetail records.
    Requires IncludeCostComparison or CostDetailsCsv. Detail, meter and comparison
    costs overlap; filter RecordType before summing.
    .PARAMETER IncludeWorkloadBaseline
    Adds normalized measured/billing workload rows and capacity quantity comparisons
    for completed UTC months. Requires a billing source and automatically collects
    transaction detail and capacity. Does not select prices or estimate scenarios.
    .PARAMETER CostDetailsCsv
    Complete actual-cost usage-details CSV files, including all report partitions.
    Adds cost comparisons without making Cost Management requests.
    .EXAMPLE
    . .\PowerShell\StorageMetrics\Get-AzStorageTransactionMetric.ps1
    $ids | Get-AzStorageTransactionMetric -StartTime '2026-09-01T00:00:00Z' -EndTime '2026-10-01T00:00:00Z' -IncludeDetail
    .OUTPUTS
    System.Management.Automation.PSCustomObject
    .NOTES
    Requires PowerShell 7 and Az.Accounts. See StorageTransactionMetrics.md for
    mappings, RBAC, missing-data semantics, and query acceleration limitations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ResourceId,

        [Parameter(Mandatory)]
        [datetimeoffset]$StartTime,

        [Parameter(Mandatory)]
        [datetimeoffset]$EndTime,

        [ValidateRange(1, 744)]
        [int]$ChunkHours = 24,

        [ValidateSet('Month', 'Chunk')]
        [string]$SummaryPeriod = 'Month',

        [switch]$IncludeDetail,

        [switch]$IncludeCapacity,

        [switch]$IncludeCurrentCapacity,

        [switch]$IncludeCostComparison,

        [ValidateRange(1, 60)]
        [int]$CostReportTimeoutMinutes = 10,

        [switch]$IncludeCostDetail,

        [switch]$IncludeWorkloadBaseline,

        [ValidateNotNullOrEmpty()]
        [string[]]$CostDetailsCsv,

        [int]$MaxRetry = 4,

        [switch]$AllowRecentData
    )

    begin {
        $start = $StartTime.ToUniversalTime()
        $end = $EndTime.ToUniversalTime()
        if ($MaxRetry -lt 0) { throw 'MaxRetry must be nonnegative.' }
        $now = [datetimeoffset]::UtcNow
        if ($start -ge $end -or $end -gt $now) {
            throw 'StartTime must precede EndTime; EndTime cannot be in the future.'
        }
        if (-not $AllowRecentData -and $end -gt $now.AddHours(-3)) {
            throw 'EndTime must be at least three hours before the current UTC time to allow Azure Monitor ingestion. Use -AllowRecentData to override.'
        }
        if ($start.Ticks % [timespan]::TicksPerMinute -or $end.Ticks % [timespan]::TicksPerMinute) {
            throw 'StartTime and EndTime must be aligned to whole minutes.'
        }
        $collectCapacity = $IncludeCapacity -or $IncludeWorkloadBaseline
        $collectDetail = $IncludeDetail -or $IncludeWorkloadBaseline
        if ($collectCapacity -and ($start.Ticks % [timespan]::TicksPerHour -or $end.Ticks % [timespan]::TicksPerHour)) {
            throw 'IncludeCapacity requires StartTime and EndTime aligned to whole hours.'
        }
        if ($start -lt [datetimeoffset]::UtcNow.AddDays(-93)) {
            throw 'StartTime is outside the 93-day Azure Monitor platform metric retention window.'
        }
        $compareCosts = $IncludeCostComparison -or [bool]$CostDetailsCsv
        if ($IncludeCostDetail -and -not $compareCosts) {
            throw 'IncludeCostDetail requires IncludeCostComparison or CostDetailsCsv.'
        }
        if ($IncludeWorkloadBaseline -and -not $compareCosts) {
            throw 'IncludeWorkloadBaseline requires IncludeCostComparison or CostDetailsCsv.'
        }
        if ($compareCosts) {
            if ($SummaryPeriod -ne 'Month' -or $start.Day -ne 1 -or $end.Day -ne 1 -or
                $start.TimeOfDay -ne [timespan]::Zero -or $end.TimeOfDay -ne [timespan]::Zero) {
                throw 'Cost comparison requires completed UTC calendar months and SummaryPeriod Month.'
            }

        }
        $comparisonRecords = [System.Collections.Generic.List[object]]::new()
        $baselineRecords = [System.Collections.Generic.List[object]]::new()
        $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $contexts = @(Get-AzContext -ListAvailable -ErrorAction Stop)
        $categories = @('Reads', 'Writes', 'IterativeReads', 'IterativeWrites',
            'AllOtherOperations', 'ListAndCreateContainer', 'Free', 'Unmapped')

        $blobMap = $script:StorageApiMaps.Blob
        $lakeMap = $script:StorageApiMaps.DataLake
        $v1Map = $script:StorageApiMaps.GPv1
    }

    process {
        foreach ($item in $ResourceId) {
            if ($item -notmatch '^/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/([^/?#]+)/providers/Microsoft\.Storage/storageAccounts/([a-z0-9]{3,24})$') {
                throw "Expected a storage account ARM resource ID, not a service ID: $item"
            }
            $parsedSubscription = [guid]::Parse($Matches[1])
            if ($parsedSubscription -eq [guid]::Empty) { throw 'Subscription ID cannot be empty.' }
            [void]$ids.Add($item)
        }
    }

    end {
        foreach ($id in $ids) {
            $parts = $id.Split('/')
            $subscription = $parts[2]
            $resourceGroup = $parts[4]
            $accountName = $parts[8]
            $account = @{ sku = @{}; properties = @{} }
            $subscriptionName = $null
            $configurationObservedAt = $null
            $chunkStart = $start
            $chunkEnd = $end
            $records = [System.Collections.Generic.List[object]]::new()
            $collected = $false
            $recordParameters = @{
                Account = $account; Id = $id; Subscription = $subscription
                SubscriptionName = $subscriptionName; ResourceGroup = $resourceGroup
                AccountName = $accountName; ConfigurationObservedAt = $configurationObservedAt
            }
            try {
                $matchingContexts = @($contexts | Where-Object { $_.Subscription.Id -eq $subscription })
                if ($matchingContexts.Count -eq 0) {
                    throw "No saved Az context for subscription $subscription. Sign in to that subscription first."
                }
                if ($matchingContexts.Count -gt 1) {
                    throw "Multiple saved Az contexts for subscription $subscription. Retain one unambiguous context before collecting."
                }
                $context = $matchingContexts[0]
                $nameProperty = $context.Subscription.PSObject.Properties['Name']
                if ($context.Subscription -is [System.Collections.IDictionary]) {
                    $subscriptionName = $context.Subscription['Name']
                } elseif ($null -ne $nameProperty) {
                    $subscriptionName = $nameProperty.Value
                }
                $recordParameters.SubscriptionName = $subscriptionName
                $account = Invoke-StorageMetricRequest -Path "${id}?api-version=2023-05-01" -Context $context -MaxRetry $MaxRetry
                $configurationObservedAt = [datetimeoffset]::UtcNow.ToString('o')
                $recordParameters.Account = $account
                $recordParameters.ConfigurationObservedAt = $configurationObservedAt
                if (-not $account['kind'] -or $account['sku'] -isnot [hashtable] -or
                    -not $account['sku']['name'] -or $account['properties'] -isnot [hashtable]) {
                    throw 'Account response is missing kind, sku or properties.'
                }
                if ($account.kind -eq 'FileStorage') { throw 'FileStorage accounts are outside Blob/ADLS scope.' }
                $map = $null
                $supportsLake = $false
                if (($account.kind -eq 'StorageV2' -and $account.sku.name -like 'Standard_*') -or
                    ($account.kind -eq 'BlockBlobStorage' -and $account.sku.name -like 'Premium_*')) {
                    $map = $blobMap
                    $supportsLake = $true
                } elseif ($account.kind -eq 'Storage' -and $account.sku.name -like 'Standard_*') {
                    $map = $v1Map
                } else {
                    Write-Warning "$id has no account column in the documented mapping; requests will be Unmapped."
                }
                for ($chunkStart = $start; $chunkStart -lt $end; $chunkStart = $chunkEnd) {
                    $requestedEnd = $chunkStart.AddHours($ChunkHours)
                    if ($requestedEnd -gt $end) { $requestedEnd = $end }
                    if ($SummaryPeriod -eq 'Month') {
                        $nextMonth = [datetimeoffset]::new($chunkStart.Year, $chunkStart.Month, 1, 0, 0, 0, [timespan]::Zero).AddMonths(1)
                        if ($requestedEnd -gt $nextMonth) { $requestedEnd = $nextMonth }
                    }
                    $pendingWindows = [System.Collections.Generic.Stack[object]]::new()
                    $pendingWindows.Push([pscustomobject]@{ Start = $chunkStart; End = $requestedEnd })
                    while ($pendingWindows.Count) {
                        $window = $pendingWindows.Pop()
                        $chunkStart = $window.Start
                        $chunkEnd = $window.End
                        $result = Get-TransactionChunkRecords -WindowStart $chunkStart -WindowEnd $chunkEnd `
                            -Context $context -AccountMap $map -SupportsLake $supportsLake `
                            -RecordParameters $recordParameters -LakeMap $lakeMap -Categories $categories `
                            -CollectDetail $collectDetail -SummaryPeriod $SummaryPeriod -MaxRetry $MaxRetry
                        if ($result.NeedsSplit) {
                            $windowHours = ($chunkEnd - $chunkStart).TotalHours
                            if ($windowHours -le 1) {
                                throw "$($result.Message) Minimum one-hour window reached."
                            }
                            $splitMinutes = [math]::Floor(($chunkEnd - $chunkStart).TotalMinutes / 2)
                            $splitAt = $chunkStart.AddMinutes($splitMinutes)
                            if ($splitAt -le $chunkStart -or $splitAt -ge $chunkEnd) {
                                throw "$($result.Message) The window cannot be split further."
                            }
                            $pendingWindows.Push([pscustomobject]@{ Start = $splitAt; End = $chunkEnd })
                            $pendingWindows.Push([pscustomobject]@{ Start = $chunkStart; End = $splitAt })
                            continue
                        }
                        foreach ($record in $result.Records) { $records.Add($record) }
                    }
                    $chunkEnd = $requestedEnd
                }
                if ($SummaryPeriod -eq 'Month') {
                    $monthlyRecords = @(ConvertTo-MonthlyRecord -Records $records.ToArray() -Start $start -End $end)
                    if ($compareCosts) {
                        foreach ($record in $monthlyRecords) { $comparisonRecords.Add($record) }
                    }
                    if ($IncludeWorkloadBaseline) {
                        foreach ($record in $monthlyRecords) { $baselineRecords.Add($record) }
                    }
                    $monthlyRecords | Set-StorageRecordType
                } else {
                    $records | Set-StorageRecordType
                }
                $collected = $true
            } catch {
                # Discard this account's buffered chunks rather than returning partial success.
                $message = "Failed collecting ${id}: $($_.Exception.Message)"
                Write-Error -Message $message -ErrorId 'StorageTransactionCollectionFailed' -Category InvalidResult -TargetObject $id
                New-TransactionRecord @recordParameters -ChunkStart $chunkStart -ChunkEnd $chunkEnd -SummaryPeriod $SummaryPeriod -Type 'Error' -Status 'Failed' -Completeness 'Failed' -Message $message | Set-StorageRecordType
            }
            if ($collectCapacity -and $collected) {
                $template = $records[0]
                try {
                    $capacityRecords = @(Get-StorageCapacityRecord -Template $template -Context $context `
                        -StartTime $start -EndTime $end -ChunkHours $ChunkHours -MaxRetry $MaxRetry -SummaryPeriod $SummaryPeriod)
                    if ($IncludeWorkloadBaseline) {
                        foreach ($record in $capacityRecords) { $baselineRecords.Add($record) }
                    }
                    $capacityRecords | Set-StorageRecordType
                } catch {
                    $message = "Failed collecting capacity for ${id}: $($_.Exception.Message)"
                    Write-Error -Message $message -ErrorId 'StorageCapacityCollectionFailed' -Category InvalidResult -TargetObject $id
                    $failure = $template.PSObject.Copy()
                    $failure.RecordType = 'CapacityError'
                    $failure.StartTime = $start.ToString('o')
                    $failure.EndTime = $end.ToString('o')
                    $failure.Month = $null
                    $failure.SummaryPeriod = $SummaryPeriod
                    $failure.IsPartialMonth = $null
                    $failure.QueryWindowHours = $null
                    $failure.RequestCount = $null
                    $failure.CountStatus = $null
                    $failure.QuantityBasis = 'AzureMonitorSampledUsedCapacity'
                    $failure.CapacityStatus = 'Failed'
                    $failure.CompletenessStatus = 'Failed'
                    $failure.Message = $message
                    if ($IncludeWorkloadBaseline) { $baselineRecords.Add($failure) }
                    $failure | Set-StorageRecordType
                }
            }
            if ($IncludeCurrentCapacity -and $collected) {
                $template = $records[0]
                $snapshotEnd = [datetimeoffset]::UtcNow
                $snapshotEnd = $snapshotEnd.AddTicks(-($snapshotEnd.Ticks % [timespan]::TicksPerHour))
                $snapshotStart = $snapshotEnd.AddHours(-24)
                try {
                    Get-StorageCapacityRecord -Template $template -Context $context `
                        -StartTime $snapshotStart -EndTime $snapshotEnd -ChunkHours 24 -MaxRetry $MaxRetry `
                        -SummaryPeriod Chunk -CurrentSnapshot | Set-StorageRecordType
                } catch {
                    $message = "Failed collecting current capacity for ${id}: $($_.Exception.Message)"
                    Write-Error -Message $message -ErrorId 'StorageCurrentCapacityCollectionFailed' -Category InvalidResult -TargetObject $id
                    $failure = $template.PSObject.Copy()
                    $failure.RecordType = 'CurrentCapacityError'
                    $failure.StartTime = $snapshotStart.ToString('o')
                    $failure.EndTime = $snapshotEnd.ToString('o')
                    $failure.Month = $null
                    $failure.SummaryPeriod = 'Snapshot'
                    $failure.IsPartialMonth = $null
                    $failure.QueryWindowHours = $null
                    $failure.RequestCount = $null
                    $failure.CountStatus = $null
                    $failure.QuantityBasis = 'AzureMonitorLatestUsedCapacity'
                    $failure.CapacityStatus = 'Failed'
                    $failure.CompletenessStatus = 'Failed'
                    $failure.Message = $message
                    $failure | Set-StorageRecordType
                }
            }
        }
        if ($compareCosts -and $comparisonRecords.Count) {
            $costRecords = @(Get-StorageTransactionCostComparison -Records $comparisonRecords.ToArray() `
                -Contexts $contexts -CsvPaths $CostDetailsCsv -IncludeDetail:$IncludeCostDetail `
                -CostReportTimeoutMinutes $CostReportTimeoutMinutes -Policy $script:StoragePricingPolicy)
            if ($IncludeWorkloadBaseline) {
                foreach ($record in $costRecords) { $baselineRecords.Add($record) }
            }
            $costRecords | Set-StorageRecordType
        }
        if ($IncludeWorkloadBaseline -and $baselineRecords.Count) {
            Get-StorageWorkloadBaseline -Records $baselineRecords.ToArray() | Set-StorageRecordType
        }
    }
}
