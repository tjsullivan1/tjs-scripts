#Requires -Version 7.0

function Get-StorageWorkloadBaseline {
    <#
    .SYNOPSIS
    Normalizes monthly quantities and compares sampled capacity with billing.
    .DESCRIPTION
    Internal companion loaded by Get-AzStorageTransactionMetric. Measured
    requests are never converted to billable operations. Billing-derived
    quantities remain a separate record type, not independent observations.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Records)

    foreach ($source in $Records) {
        if ($source.RecordType -notin @('Detail', 'Capacity', 'IndexCapacity', 'CostMeter')) { continue }
        $record = $source.PSObject.Copy()
        $record.SourceRecordType = $source.RecordType
        $record.RecordType = 'Workload'
        $record.QuantitySource = 'AzureMonitor'
        switch ($source.RecordType) {
            'Detail' {
                $record.QuantityKind = 'ObservedRequests'
                $record.QuantityUnit = 'Requests'
                $record.QuantityBasis = 'AzureMonitorObservedRequests'
                $record.QuantityStatus = 'ObservedRequestsNotBillable'
                if ($source.Category -eq 'Free') { $record.QuantityStatus = 'DocumentedFreeRequests' }
                if ($source.Category -eq 'Unmapped') { $record.QuantityStatus = 'UnmappedRequests' }
                if ($source.CompletenessStatus -ne 'Reconciled' -or $null -eq $source.RequestCount) {
                    $record.QuantityStatus = 'MissingData'
                } else {
                    $record.Quantity = $source.RequestCount
                }
            }
            { $_ -in @('Capacity', 'IndexCapacity') } {
                $record.QuantityKind = if ($_ -eq 'Capacity') { 'UsedCapacity' } else { 'HnsIndexCapacity' }
                $record.QuantityUnit = 'GiBMonth'
                $record.QuantityStatus = 'MissingData'
                if ($_ -eq 'Capacity') {
                    $record.CapacityTierBasis = if ($source.AccountKind -eq 'Storage' -and
                        $source.SkuName -like 'Standard_*' -and $source.Tier -eq 'Untiered') {
                        'NonTieredGPv1'
                    } elseif ($source.Tier -in @('Hot', 'Cool', 'Cold', 'Archive')) {
                        'ExplicitMetricTier'
                    } else { 'Unresolved' }
                }
                if ($source.CapacityStatus -eq 'CompleteSamples' -and $null -ne $source.AverageUsedBytes) {
                    $record.Quantity = $source.AverageUsedBytes / [decimal]1073741824
                    $record.QuantityStatus = 'CompleteSampleEstimate'
                }
            }
            'CostMeter' {
                $record.RecordType = 'BilledWorkload'
                $record.QuantitySource = $source.CostSource
                $record.QuantityKind = $source.BillingQuantityKind
                $record.QuantityUnit = $source.NormalizedBilledUnit
                $record.QuantityStatus = $source.BillingMappingStatus
                if ($source.HasNegativeUsageQuantity -eq $true) {
                    $record.QuantityStatus = 'BillingAdjustmentsPresent'
                } elseif ($source.ChargeType -eq 'Usage' -and $null -ne $source.NormalizedBilledQuantity) {
                    $record.Quantity = $source.NormalizedBilledQuantity
                    $record.QuantityStatus = 'BillingDerived'
                }
                if (-not $record.QuantityKind) { $record.QuantityKind = 'UnclassifiedMeter' }
            }
        }
        $record
    }

    foreach ($template in ($Records | Where-Object RecordType -eq 'AccountTotal')) {
        $period = @($Records | Where-Object { $_.ResourceId -eq $template.ResourceId -and $_.Month -eq $template.Month })
        $capacityFailed = @($Records | Where-Object { $_.ResourceId -eq $template.ResourceId -and $_.RecordType -eq 'CapacityError' }).Count -gt 0
        $billingFailed = @($period | Where-Object RecordType -eq 'CostError').Count -gt 0
        $billingEvidence = @($period | Where-Object RecordType -in @('CostMeter', 'CostComparison'))
        $groups = [System.Collections.Generic.List[object]]::new()
        $capacities = @($period | Where-Object RecordType -eq 'Capacity')
        $meters = @($period | Where-Object { $_.RecordType -eq 'CostMeter' -and $_.ChargeType -eq 'Usage' })
        $blobMeters = @($meters | Where-Object BillingQuantityKind -eq 'Capacity')
        $nonTieredGPv1 = $template.AccountKind -eq 'Storage' -and
            $template.SkuName -like 'Standard_*' -and $capacities.Count -gt 0 -and
            -not @($capacities | Where-Object Tier -ne 'Untiered').Count
        $tiers = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($capacity in $capacities) { [void]$tiers.Add([string]$capacity.Tier) }
        foreach ($meter in $blobMeters) {
            if ($nonTieredGPv1 -and -not $meter.BillingTier -and $meter.MeterSubCategory -eq 'General Block Blob') {
                [void]$tiers.Add('Untiered')
            } else { [void]$tiers.Add([string]$meter.BillingTier) }
        }
        if (-not $tiers.Count) { [void]$tiers.Add('') }
        foreach ($tier in ($tiers | Sort-Object)) {
            $groups.Add(@{
                Kind = 'UsedCapacity'; Tier = $tier
                Measured = @($capacities | Where-Object { [string]$_.Tier -eq $tier })
                Billed = @($blobMeters | Where-Object {
                    [string]$_.BillingTier -eq $tier -or
                    ($nonTieredGPv1 -and $tier -eq 'Untiered' -and -not $_.BillingTier -and
                        $_.MeterSubCategory -eq 'General Block Blob')
                })
            })
        }
        $index = @($period | Where-Object RecordType -eq 'IndexCapacity')
        $indexMeters = @($meters | Where-Object BillingQuantityKind -eq 'HnsIndexCapacity')
        if ($template.IsHnsEnabled -eq $true -or $index.Count -or $indexMeters.Count) {
            $groups.Add(@{ Kind = 'HnsIndexCapacity'; Tier = $null; Measured = $index; Billed = $indexMeters })
        }
        foreach ($group in $groups) {
            $measured = $group.Measured
            $billed = $group.Billed
            $comparison = $template.PSObject.Copy()
            $comparison.RecordType = 'CapacityComparison'
            $comparison.RequestCount = $null
            $comparison.CountStatus = $null
            $comparison.QuantityKind = $group.Kind
            $comparison.QuantityUnit = 'GiBMonth'
            $comparison.Tier = if ($group.Tier) { $group.Tier } else { $null }
            if ($group.Kind -eq 'UsedCapacity') {
                $comparison.CapacityTierBasis = if ($nonTieredGPv1 -and $group.Tier -eq 'Untiered') {
                    'NonTieredGPv1'
                } elseif ($group.Tier -in @('Hot', 'Cool', 'Cold', 'Archive')) {
                    'ExplicitMetricTier'
                } else { 'Unresolved' }
            }
            $comparison.QuantityBasis = 'SampledUsedCapacityVersusBillingReportedUsage'
            $comparison.QuantitySource = 'AzureMonitorAndBilling'
            $comparison.QuantityStatus = 'ComparisonOnly'
            $comparison.CompletenessStatus = 'NotBillingValidation'
            if ($billingEvidence.Count) {
                $comparison.BillingCoverageStatus = $billingEvidence[0].BillingCoverageStatus
                $comparison.CostSource = $billingEvidence[0].CostSource
            }
            $comparison.ComparisonStatus = 'NoMatchingBillingMeter'
            $comparison.CapacityStatus = 'IncompleteSamples'
            if ($measured.Count -and -not @($measured | Where-Object {
                $_.CapacityStatus -ne 'CompleteSamples' -or $null -eq $_.AverageUsedBytes
            }).Count) {
                $comparison.CapacityStatus = 'CompleteSamples'
                $comparison.ObservedCapacityGiBMonth = [decimal]0
                foreach ($capacity in $measured) {
                    $comparison.ObservedCapacityGiBMonth += $capacity.AverageUsedBytes / [decimal]1073741824
                }
            } else {
                $comparison.ComparisonStatus = 'MetricsIncomplete'
            }
            if ($billed.Count) {
                $comparison.BillingCoverageStatus = $billed[0].BillingCoverageStatus
                $comparison.HasNegativeUsageQuantity = @($billed | Where-Object HasNegativeUsageQuantity -eq $true).Count -gt 0
                $contexts = @($billed | Group-Object -CaseSensitive -Property {
                    ConvertTo-Json -InputObject @($_.Currency, $_.MeterRegion, $_.BillingRedundancy) -Compress
                })
                if (@($billed | Where-Object {
                    $_.NormalizedBilledUnit -ne 'GiBMonth' -or $null -eq $_.NormalizedBilledQuantity
                }).Count) {
                    $comparison.ComparisonStatus = 'UnverifiedUnit'
                } elseif ($contexts.Count -ne 1) {
                    $comparison.ComparisonStatus = 'AmbiguousBillingContext'
                } elseif (@($billed | Where-Object {
                    $_.HasNegativeUsageQuantity -eq $true -or $_.NormalizedBilledQuantity -lt 0
                }).Count) {
                    $comparison.ComparisonStatus = 'BillingAdjustmentsPresent'
                } else {
                    $comparison.BilledCapacityGiBMonth = [decimal]0
                    foreach ($meter in $billed) { $comparison.BilledCapacityGiBMonth += $meter.NormalizedBilledQuantity }
                    $comparison.Currency = $billed[0].Currency
                    $comparison.BillingRedundancy = $billed[0].BillingRedundancy
                    $comparison.MeterRegion = $billed[0].MeterRegion
                    if ($null -eq $comparison.ObservedCapacityGiBMonth) {
                        $comparison.ComparisonStatus = 'MetricsIncomplete'
                    } else {
                        $comparison.CapacityDifferenceGiBMonth = $comparison.ObservedCapacityGiBMonth - $comparison.BilledCapacityGiBMonth
                        if ($comparison.BilledCapacityGiBMonth -ne 0) {
                            $comparison.CapacityDifferencePercent = $comparison.CapacityDifferenceGiBMonth / $comparison.BilledCapacityGiBMonth * 100
                        }
                        $comparison.ComparisonStatus = if ($comparison.CapacityDifferenceGiBMonth -eq 0) { 'QuantitiesMatch' } else { 'QuantitiesDiffer' }
                    }
                }
            }
            if ($group.Kind -eq 'UsedCapacity' -and @($measured | Where-Object {
                $_.BlobType -notin @('BlockBlob', 'AppendBlob')
            }).Count) {
                $comparison.ObservedCapacityGiBMonth = $null
                $comparison.ComparisonStatus = 'UnsupportedBlobType'
            }
            if ($group.Kind -eq 'UsedCapacity' -and $comparison.CapacityTierBasis -eq 'Unresolved') {
                $comparison.ObservedCapacityGiBMonth = $null
                $comparison.ComparisonStatus = 'TierUnresolved'
            }
            if ($capacityFailed) {
                $comparison.ComparisonStatus = 'MetricsFailed'
                $comparison.CapacityStatus = 'Failed'
            }
            if ($billingFailed) {
                $comparison.ComparisonStatus = 'BillingUnavailable'
            }
            if ($comparison.ComparisonStatus -notin @('QuantitiesMatch', 'QuantitiesDiffer')) {
                $comparison.CapacityDifferenceGiBMonth = $null
                $comparison.CapacityDifferencePercent = $null
            }
            $comparison.Message = switch ($comparison.ComparisonStatus) {
                'QuantitiesMatch' { 'Sampled used capacity equals reported billed capacity; this does not validate billability, prices or billing completeness.' }
                'QuantitiesDiffer' { 'Sampled used capacity differs from reported billed capacity; investigate sampling, billing semantics, configuration history and report coverage.' }
                'TierUnresolved' { 'Capacity tier is missing or is not Hot/Cool/Cold/Archive; the account default tier is not used to assign historical quantities.' }
                'AmbiguousBillingContext' { 'Capacity billing spans different currencies, meter regions or redundancies; quantities were not combined.' }
                'BillingAdjustmentsPresent' { 'Negative usage quantities require review before establishing a normalized workload.' }
                'MetricsFailed' { 'Capacity collection failed; original CapacityError records contain the failure.' }
                'BillingUnavailable' { 'Billing retrieval/import failed; original CostError records contain the failure.' }
                'MetricsIncomplete' { 'Complete sampled capacity is unavailable; available-hour averages were not substituted.' }
                'UnsupportedBlobType' { 'The tier contains blob types that cannot be compared with the recognized block-blob capacity meters.' }
                'UnverifiedUnit' { 'At least one capacity billing unit could not be normalized to GiBMonth.' }
                'NoMatchingBillingMeter' { 'No matching usage capacity meter was returned; absent billing is not a confirmed zero.' }
            }
            $comparison
        }
    }
}
