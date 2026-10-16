function Get-StorageCapacityRecord {
    <#
    .SYNOPSIS
    Collects historical used-capacity samples for the transaction collector.
    .DESCRIPTION
    Internal companion loaded by Get-AzStorageTransactionMetric. Uses hourly
    averages, not provisioned capacity or billed quantities. Buffers account
    results so a failed query cannot emit a partial capacity dataset.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Template,
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][datetimeoffset]$StartTime,
        [Parameter(Mandatory)][datetimeoffset]$EndTime,
        [int]$ChunkHours,
        [string]$SummaryPeriod,
        [switch]$CurrentSnapshot,
        [int]$MaxRetry = 4
    )

    $output = [System.Collections.Generic.List[object]]::new()
    for ($periodStart = $StartTime; $periodStart -lt $EndTime; $periodStart = $periodEnd) {
        $monthStart = [datetimeoffset]::new($periodStart.Year, $periodStart.Month, 1, 0, 0, 0, [timespan]::Zero)
        $periodEnd = if ($SummaryPeriod -eq 'Month') { $monthStart.AddMonths(1) } else { $periodStart.AddHours($ChunkHours) }
        if ($periodEnd -gt $EndTime) { $periodEnd = $EndTime }
        $groups = @{}
        $reconciliationMissing = $false
        $maxQueryWindowHours = 0
        for ($first = $periodStart; $first -lt $periodEnd; $first = $last) {
            $last = $first.AddHours($ChunkHours)
            if ($last -gt $periodEnd) { $last = $periodEnd }
            $pendingWindows = [System.Collections.Generic.Stack[object]]::new()
            $pendingWindows.Push([pscustomobject]@{ First = $first; Last = $last })
            while ($pendingWindows.Count) {
                $window = $pendingWindows.Pop()
                $windowResult = Get-CapacityWindow -First $window.First -Last $window.Last -Template $Template -Context $Context -MaxRetry $MaxRetry
                if ($windowResult.NeedsSplit) {
                    $windowHours = ($window.Last - $window.First).TotalHours
                    if ($windowHours -le 1) {
                        throw "$($windowResult.Message) Minimum one-hour window reached."
                    }
                    $splitHours = [math]::Floor($windowHours / 2)
                    $splitAt = $window.First.AddHours($splitHours)
                    if ($splitAt -le $window.First -or $splitAt -ge $window.Last) {
                        throw "$($windowResult.Message) The window cannot be split further."
                    }
                    $pendingWindows.Push([pscustomobject]@{ First = $splitAt; Last = $window.Last })
                    $pendingWindows.Push([pscustomobject]@{ First = $window.First; Last = $splitAt })
                    continue
                }
                $maxQueryWindowHours = [math]::Max(
                    $maxQueryWindowHours, ($window.Last - $window.First).TotalHours
                )
                $reconciliationMissing = $reconciliationMissing -or $windowResult.ReconciliationMissing
                foreach ($key in $windowResult.Groups.Keys) {
                    $group = $windowResult.Groups[$key]
                    if (-not $groups.ContainsKey($key)) {
                        $groups[$key] = @{
                            Type = $group.Type; Metric = $group.Metric; Tier = $group.Tier
                            BlobType = $group.BlobType; Points = @{}
                        }
                    }
                    foreach ($time in $group.Points.Keys) {
                        if ($groups[$key].Points.ContainsKey($time)) { throw 'Overlapping capacity query windows.' }
                        $groups[$key].Points[$time] = $group.Points[$time]
                    }
                }
            }
        }
        if (-not @($groups.Values | Where-Object Type -eq 'Capacity').Count) {
            $groups['UnavailableSplit'] = @{ Type = 'Capacity'; Metric = 'BlobCapacity'; Tier = $null; BlobType = $null; Points = @{} }
        }
        if ($CurrentSnapshot) {
            $blobGroups = @($groups.Values | Where-Object Type -in @('Capacity', 'CapacityAccountTotal'))
            $sampleTime = $null
            for ($time = $periodEnd.AddHours(-1); $time -ge $periodStart; $time = $time.AddHours(-1)) {
                $key = $time.ToString('o')
                if (-not @($blobGroups | Where-Object { $null -eq $_.Points[$key] }).Count) {
                    $sampleTime = $time
                    break
                }
            }
            foreach ($group in ($groups.Values | Sort-Object Type, Tier, BlobType)) {
                $selectedTime = $sampleTime
                if ($group.Type -eq 'IndexCapacity') {
                    $selectedTime = $null
                    for ($time = $periodEnd.AddHours(-1); $time -ge $periodStart; $time = $time.AddHours(-1)) {
                        if ($null -ne $group.Points[$time.ToString('o')]) { $selectedTime = $time; break }
                    }
                }
                $record = $Template.PSObject.Copy()
                $record.RecordType = switch ($group.Type) {
                    'Capacity' { 'CurrentCapacity' }
                    'CapacityAccountTotal' { 'CurrentCapacityAccountTotal' }
                    'IndexCapacity' { 'CurrentIndexCapacity' }
                }
                $record.RequestCount = $null
                $record.CountStatus = $null
                $record.MetricName = $group.Metric
                $record.Tier = $group.Tier
                $record.BlobType = $group.BlobType
                $record.StartTime = $periodStart.ToString('o')
                $record.EndTime = $periodEnd.ToString('o')
                $record.Month = $null
                $record.SummaryPeriod = 'Snapshot'
                $record.IsPartialMonth = $null
                $record.QueryWindowHours = $null
                $record.QuantityBasis = 'AzureMonitorLatestUsedCapacity'
                $record.CompletenessStatus = 'SnapshotNotMonthlyCoverage'
                $record.CapacityStatus = 'Unavailable'
                $record.CapacityReconciliationStatus = if ($group.Type -eq 'IndexCapacity') { 'NotApplicable' } else { 'MissingSamples' }
                if ($null -ne $selectedTime) {
                    $record.CapacitySampleTimeUtc = $selectedTime.ToString('o')
                    $record.CapacitySampleAgeHours = ((Get-UtcNow) - $selectedTime).TotalHours
                    $record.CurrentUsedBytes = $group.Points[$selectedTime.ToString('o')]
                    $record.CurrentUsedGiB = $record.CurrentUsedBytes / [decimal]1073741824
                    $record.CapacityStatus = if ($group.Type -eq 'IndexCapacity') { 'LatestSample' } else { 'LatestReconciledSample' }
                    if ($group.Type -ne 'IndexCapacity') { $record.CapacityReconciliationStatus = 'ReconciledSample' }
                } else {
                    $record.Message = 'No usable capacity sample was found in the last 24 complete hours; capacity is unknown, not zero.'
                    Write-Warning "$($Template.ResourceId) $($group.Metric): $($record.Message)"
                }
                $output.Add($record)
            }
            continue
        }
        foreach ($group in ($groups.Values | Sort-Object Type, Tier, BlobType)) {
            $expected = [int]($periodEnd - $periodStart).TotalHours
            $observed = 0
            $byteHours = [decimal]0
            foreach ($average in $group.Points.Values) {
                if ($null -ne $average) { $observed++; $byteHours += $average }
            }
            $record = $Template.PSObject.Copy()
            $record.RecordType = $group.Type
            $record.RequestCount = $null
            $record.CountStatus = $null
            $record.MetricName = $group.Metric
            $record.Tier = $group.Tier
            $record.BlobType = $group.BlobType
            $record.StartTime = $periodStart.ToString('o')
            $record.EndTime = $periodEnd.ToString('o')
            $record.Month = $periodStart.ToString('yyyy-MM', [cultureinfo]::InvariantCulture)
            $record.SummaryPeriod = $SummaryPeriod
            $record.IsPartialMonth = $periodStart -ne $monthStart -or $periodEnd -ne $monthStart.AddMonths(1)
            $record.QueryWindowHours = if ($SummaryPeriod -eq 'Chunk' -and -not $CurrentSnapshot) {
                [decimal]$maxQueryWindowHours
            } else { $null }
            $record.ExpectedHours = $expected
            $record.ObservedHours = $observed
            $record.MissingHours = $expected - $observed
            $record.CapacityReconciliationStatus = if ($group.Type -eq 'IndexCapacity') { 'NotApplicable' } elseif ($reconciliationMissing) { 'MissingSamples' } else { 'ReconciledSamples' }
            $complete = $observed -eq $expected -and ($group.Type -eq 'IndexCapacity' -or -not $reconciliationMissing)
            $record.CapacityStatus = if ($complete) { 'CompleteSamples' } else { 'IncompleteSamples' }
            $record.CompletenessStatus = $record.CapacityStatus
            $record.QuantityBasis = 'AzureMonitorSampledUsedCapacity'
            if ($observed) {
                $record.ObservedByteHours = $byteHours
                $record.AverageObservedBytes = $byteHours / $observed
                if ($complete) { $record.AverageUsedBytes = $byteHours / $expected }
            }
            if (-not $complete) {
                Write-Warning "$($Template.ResourceId) $($record.Month) $($group.Metric): incomplete capacity samples or reconciliation."
            }
            $output.Add($record)
        }
    }
    $output.ToArray()
}
