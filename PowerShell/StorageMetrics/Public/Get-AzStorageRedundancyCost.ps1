function Get-AzStorageRedundancyCost {
    <#
    .SYNOPSIS
    Prices a current Blob or opt-in ADLS Gen2 footprint under six redundancy options.
    .DESCRIPTION
    Consumes objects from Get-AzStorageTransactionMetric, not overlapping totals.
    Holds current capacity constant and scales observed requests to ModelMonth.
    Fetches current public USD consumption prices independently of collection.
    Returns line items and partial scenario subtotals, never a complete invoice
    estimate. Retrieval, bandwidth, feature and migration costs are excluded
    explicitly. Geo-replication transfer is optional and caller-supplied.
    Endpoint schedules, premium and unresolved tiers are not guessed.
    .PARAMETER Records
    Collector objects, or its JSON imported with timestamps preserved as strings.
    Requires CurrentCapacity, AccountTotal and Detail records for each account.
    .PARAMETER ModelMonth
    Calendar month whose duration is used to scale the observed request window.
    Prices are current, not reconstructed historical rates.
    .PARAMETER LegacyTargetTier
    Explicit GPv1-to-GPv2 tier assumption for non-tiered accounts. Without it,
    legacy capacity and requests are not assigned a modern access tier.
    .PARAMETER AssumeFlatNamespace
    Explicitly assumes flat namespace only when IsHnsEnabled is null. Does not
    override a known HNS-enabled account. The assumption is recorded on each row.
    .PARAMETER PricingMode
    BlobFlat (default), BlobHns (Blob endpoint including NFS/SFTP), or AdlsGen2
    (DFS endpoint). HNS modes require a known HNS-enabled Standard StorageV2 account.
    Applies to all supplied accounts/requests; split mixed-endpoint workloads first.
    .PARAMETER Scenario
    Redundancy scenarios to estimate. Defaults to all six supported options.
    .PARAMETER EstimateGeoReplicationFromWriteBytes
    Caller-supplied replicated write volume in GiB per modeled month. Adds a
    catalog-priced transfer line for geo-redundant scenarios only.
    .EXAMPLE
    . .\PowerShell\StorageMetrics\Get-AzStorageRedundancyCost.ps1
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10'
    .EXAMPLE
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10' -PricingMode AdlsGen2
    Models the supplied HNS workload using the DFS endpoint schedule.
    .EXAMPLE
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10' -PricingMode BlobHns
    Models the supplied HNS workload using the Blob endpoint schedule (including NFS/SFTP).
    .EXAMPLE
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10' `
        -Scenario GRS, RA-GZRS -EstimateGeoReplicationFromWriteBytes 120
    Models selected scenarios with a caller-supplied monthly replicated-write assumption.
    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$Records,
        [Parameter(Mandatory)][ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$ModelMonth,
        [ValidateSet('Hot', 'Cool', 'Cold', 'Archive')][string]$LegacyTargetTier,
        [switch]$AssumeFlatNamespace,
        [ValidateSet('BlobFlat', 'BlobHns', 'AdlsGen2')][string]$PricingMode = 'BlobFlat',
        [ValidateSet('LRS', 'ZRS', 'GRS', 'GZRS', 'RA-GRS', 'RA-GZRS')]
        [string[]]$Scenario = @('LRS', 'ZRS', 'GRS', 'GZRS', 'RA-GRS', 'RA-GZRS'),
        [decimal]$EstimateGeoReplicationFromWriteBytes
    )

    $estimateParameters = @{
        ModelMonth = $ModelMonth; PricingMode = $PricingMode; LegacyTargetTier = $LegacyTargetTier
    }
    $selectedScenarios = @($Scenario | Select-Object -Unique)
    $geoReplicationScenarios = @('GRS', 'GZRS', 'RA-GRS', 'RA-GZRS')
    $estimateGeoReplication = $PSBoundParameters.ContainsKey('EstimateGeoReplicationFromWriteBytes')
    if ($estimateGeoReplication -and $EstimateGeoReplicationFromWriteBytes -lt 0) {
        throw 'EstimateGeoReplicationFromWriteBytes must be nonnegative.'
    }
    $geoReplicationCatalogNeeded = $estimateGeoReplication -and
        @($selectedScenarios | Where-Object { $_ -in $geoReplicationScenarios }).Count -gt 0

    $modelStart = [datetimeoffset]::ParseExact("$ModelMonth-01", 'yyyy-MM-dd',
        [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
    $modelHours = [decimal]($modelStart.AddMonths(1) - $modelStart).TotalHours
    $priceTime = [datetimeoffset]::UtcNow
    $estimateParameters.PriceTime = $priceTime
    $catalogs = @{}
    $skuRedundancyMap = @{
        LRS = 'LRS'; ZRS = 'ZRS'; GRS = 'GRS'; GZRS = 'GZRS'
        RAGRS = 'RA-GRS'; RAGZRS = 'RA-GZRS'
    }
    if (@($Records | Where-Object RecordType -in @('Error', 'CurrentCapacityError')).Count) {
        throw 'Resolve collector failures before pricing; failed accounts must not be silently omitted.'
    }
    $snapshots = @($Records | Where-Object RecordType -eq 'CurrentCapacity')
    if (-not $snapshots.Count) { throw 'Records must include CurrentCapacity; collect with IncludeCurrentCapacity.' }
    foreach ($total in ($Records | Where-Object RecordType -eq 'AccountTotal')) {
        if (-not @($snapshots | Where-Object ResourceId -eq $total.ResourceId).Count) {
            throw "Missing current capacity snapshot for $($total.ResourceId); do not omit failed accounts."
        }
    }

    foreach ($accountGroup in ($snapshots | Group-Object ResourceId)) {
        $account = $accountGroup.Group[0]
        $skuMatch = [regex]::Match([string]$account.SkuName,
            '_(RAGZRS|RAGRS|GZRS|GRS|ZRS|LRS)$',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $currentRedundancy = if ($skuMatch.Success) {
            $skuRedundancyMap[$skuMatch.Groups[1].Value.ToUpperInvariant()]
        } else { $null }
        $flatNamespace = $account.IsHnsEnabled -eq $false -or
            ($null -eq $account.IsHnsEnabled -and $AssumeFlatNamespace)
        $hnsMode = $PricingMode -ne 'BlobFlat'
        $supportedCapacityTypes = @('BlockBlob', 'AppendBlob')
        if ($hnsMode) { $supportedCapacityTypes += 'Azure Data Lake Storage' }
        $supportedConfiguration = if ($hnsMode) {
            $account.IsHnsEnabled -eq $true -and $account.AccountKind -eq 'StorageV2'
        } else {
            $flatNamespace -and $account.AccountKind -in @('StorageV2', 'BlobStorage', 'Storage')
        }
        $supportedConfiguration = $supportedConfiguration -and $account.SkuName -like 'Standard_*'
        $namespaceBasis = if ($account.IsHnsEnabled -eq $false) { 'CurrentConfigurationFlat' }
            elseif ($null -eq $account.IsHnsEnabled -and $AssumeFlatNamespace) { 'AssumedFlatWhenUnspecified' }
            elseif ($account.IsHnsEnabled -eq $true) { 'CurrentConfigurationHns' }
            else { 'UnsupportedOrUnknown' }
        if (@($accountGroup.Group | Group-Object Tier, BlobType | Where-Object Count -gt 1).Count) {
            throw 'Duplicate current capacity tier/type records; supply one snapshot per account.'
        }
        if (@($accountGroup.Group | Group-Object CapacitySampleTimeUtc).Count -ne 1) {
            throw 'Current capacity tier/type records must share a sample timestamp.'
        }
        $accountRows = @($Records | Where-Object ResourceId -eq $account.ResourceId)
        $indexSnapshots = @($accountRows | Where-Object RecordType -eq 'CurrentIndexCapacity')
        if ($hnsMode -and $indexSnapshots.Count -gt 1) {
            throw 'Duplicate current index capacity records; supply one index snapshot per account.'
        }
        $totals = @($accountRows | Where-Object RecordType -eq 'AccountTotal' | Sort-Object { [datetimeoffset]$_.StartTime })
        $details = @($accountRows | Where-Object RecordType -eq 'Detail')
        $sourceStart = $null; $sourceEnd = $null; $scale = $null
        if ($totals.Count -and -not @($totals | Where-Object CompletenessStatus -ne 'Reconciled').Count) {
            $sourceStart = [datetimeoffset]$totals[0].StartTime
            $sourceEnd = $sourceStart
            foreach ($total in $totals) {
                if ([datetimeoffset]$total.StartTime -ne $sourceEnd -or [datetimeoffset]$total.EndTime -le $sourceEnd) {
                    throw 'AccountTotal transaction windows must be contiguous and nonoverlapping.'
                }
                $sourceEnd = [datetimeoffset]$total.EndTime
            }
            $scale = $modelHours / [decimal]($sourceEnd - $sourceStart).TotalHours
        }
        foreach ($detail in $details) {
            if (-not @($totals | Where-Object {
                [datetimeoffset]$_.StartTime -eq [datetimeoffset]$detail.StartTime -and
                [datetimeoffset]$_.EndTime -eq [datetimeoffset]$detail.EndTime
            }).Count) { throw 'Detail period must match an AccountTotal period.' }
        }
        foreach ($total in $totals) {
            if ($total.CompletenessStatus -ne 'Reconciled') { continue }
            $periodDetails = @($details | Where-Object {
                [datetimeoffset]$_.StartTime -eq [datetimeoffset]$total.StartTime -and
                [datetimeoffset]$_.EndTime -eq [datetimeoffset]$total.EndTime
            })
            $sum = [decimal]0
            foreach ($detail in $periodDetails) {
                if ($null -eq $detail.RequestCount -or [decimal]$detail.RequestCount -lt 0) {
                    throw 'Detail counts must be nonnegative numeric observations.'
                }
                $sum += [decimal]$detail.RequestCount
            }
            if ($null -eq $total.RequestCount -or $sum -ne [decimal]$total.RequestCount) {
                throw 'Detail counts must reconcile with AccountTotal; export IncludeDetail.'
            }
        }
        $region = [string]$account.Location
        if (-not $catalogs.ContainsKey($region)) { $catalogs[$region] = @(Get-RetailCatalog -Region $region -PricingMode $PricingMode -GeoReplicationCatalogNeeded $geoReplicationCatalogNeeded -Policy $script:StoragePricingPolicy) }
        $scenarioOutput = [System.Collections.Generic.List[object]]::new()
        $scenarioSummaries = [System.Collections.Generic.List[object]]::new()
        foreach ($scenario in $selectedScenarios) {
            $scenarioIncludesGeoReplicationTransfer = $estimateGeoReplication -and
                $scenario -in $geoReplicationScenarios
            $productPolicy = $script:StoragePricingPolicy.RetailProducts.Values[$PricingMode]
            $product = $productPolicy.Default
            if ($productPolicy.ContainsKey('ZonalScenarios') -and $scenario -in $productPolicy.ZonalScenarios) {
                $product = $productPolicy.Zonal
            }
            $lines = [System.Collections.Generic.List[object]]::new()
            foreach ($capacityGroup in ($accountGroup.Group | Group-Object Tier)) {
                $capacity = $capacityGroup.Group[0]
                $line = New-EstimateRecord @estimateParameters -Account $account -Scenario $scenario -Type 'Estimate' -Component 'Capacity' `
                    -IncludeGeoReplicationTransfer:$scenarioIncludesGeoReplicationTransfer
                $line.NamespaceBasis = $namespaceBasis
                $line.Tier = $capacity.Tier
                $line.QuantityBasis = 'CurrentCapacityHeldConstantForModelMonth'
                $line.CapacitySampleTimeUtc = $capacity.CapacitySampleTimeUtc
                $line.QuantityUnit = 'GiBMonth'
                if ($account.AccountKind -eq 'Storage' -and $line.Tier -eq 'Untiered' -and $LegacyTargetTier) {
                    $line.Tier = $LegacyTargetTier
                    $line.QuantityBasis = 'CurrentGPv1CapacityHeldConstantInAssumedGPv2Tier'
                }
                $line.Status = 'UnsupportedConfiguration'
                if ($supportedConfiguration -and
                    -not @($capacityGroup.Group | Where-Object BlobType -notin $supportedCapacityTypes).Count) {
                    if ($line.Tier -notin @('Hot', 'Cool', 'Cold', 'Archive')) {
                        $line.Status = 'TierUnresolved'
                    } elseif ($line.Tier -eq 'Archive' -and $scenario -in @('ZRS', 'GZRS', 'RA-GZRS')) {
                        $line.Status = 'IneligibleArchive'
                    } elseif (@($capacityGroup.Group | Where-Object {
                        $_.CapacityStatus -ne 'LatestReconciledSample' -or $null -eq $_.CurrentUsedGiB
                    }).Count) {
                        $line.Status = 'CapacityUnavailable'
                    } else {
                        $line.Quantity = [decimal]0
                        foreach ($split in $capacityGroup.Group) {
                            if ([decimal]$split.CurrentUsedGiB -lt 0) { throw 'Capacity cannot be negative.' }
                            $line.Quantity += [decimal]$split.CurrentUsedGiB
                        }
                        $line.ProductName = $product
                        $line.SkuName = "$($line.Tier) $scenario"
                        Set-RetailCost -PriceTime $priceTime -Line $line -Catalog $catalogs[$region] `
                            -MeterNames @("$($line.Tier) $scenario Data Stored") -Unit '1 GB/Month'
                    }
                }
                $lines.Add($line)
            }
            if ($hnsMode) {
                $line = New-EstimateRecord @estimateParameters -Account $account -Scenario $scenario -Type 'Estimate' -Component 'HnsIndexCapacity' `
                    -IncludeGeoReplicationTransfer:$scenarioIncludesGeoReplicationTransfer
                $line.NamespaceBasis = $namespaceBasis
                $line.Tier = 'Hot'
                $line.QuantityUnit = 'GiBMonth'
                $line.QuantityBasis = 'CurrentIndexCapacityHeldConstantForModelMonthSeparateFromBlobCapacity'
                $line.ProductName = $script:StoragePricingPolicy.RetailProducts.Index
                $line.SkuName = "Hot $scenario"
                $line.Status = 'UnsupportedConfiguration'
                if ($supportedConfiguration) {
                    $line.Status = 'CapacityUnavailable'
                    if ($indexSnapshots.Count -eq 1) {
                        $index = $indexSnapshots[0]
                        $line.CapacitySampleTimeUtc = $index.CapacitySampleTimeUtc
                        if ($index.CapacityStatus -eq 'LatestSample' -and $null -ne $index.CurrentUsedGiB) {
                            if ([decimal]$index.CurrentUsedGiB -lt 0) { throw 'Index capacity cannot be negative.' }
                            $line.Quantity = [decimal]$index.CurrentUsedGiB
                            Set-RetailCost -PriceTime $priceTime -Line $line -Catalog $catalogs[$region] `
                                -MeterNames @("Hot $scenario Index") -Unit '1 GB/Month'
                        }
                    }
                }
                $lines.Add($line)
            }
            if ($scenarioIncludesGeoReplicationTransfer) {
                $line = New-EstimateRecord @estimateParameters -Account $account -Scenario $scenario `
                    -Type 'Estimate' -Component 'GeoReplicationTransfer' `
                    -IncludeGeoReplicationTransfer
                $line.NamespaceBasis = $namespaceBasis
                $line.Quantity = [decimal]$EstimateGeoReplicationFromWriteBytes * [decimal]1.073741824
                $line.QuantityUnit = 'GB'
                $line.QuantityBasis = 'CallerSuppliedAssumption'
                $line.ProductName = $script:StoragePricingPolicy.RetailProducts.GeoReplication
                $line.SkuName = 'Geo-Replication'
                $line.Message = 'Caller-supplied GiB/month converted to decimal GB to match the retail meter unit.'
                Set-RetailCost -PriceTime $priceTime -Line $line -Catalog $catalogs[$region] `
                    -MeterNames @('Geo-Replication Data Transfer') -Unit '1 GB'
                $lines.Add($line)
            }
            foreach ($group in ($details | Group-Object Tier, Category, GeoType)) {
                $detail = $group.Group[0]
                $line = New-EstimateRecord @estimateParameters -Account $account -Scenario $scenario -Type 'Estimate' `
                    -Component $detail.Category `
                    -IncludeGeoReplicationTransfer:$scenarioIncludesGeoReplicationTransfer
                $line.NamespaceBasis = $namespaceBasis
                $line.Tier = $detail.Tier
                $line.GeoType = $detail.GeoType
                if ($account.AccountKind -eq 'Storage' -and $LegacyTargetTier) { $line.Tier = $LegacyTargetTier }
                $line.QuantityUnit = 'EstimatedOperations'
                $line.QuantityBasis = 'ObservedRequestsScaledToModelMonthNotBillableCounts'
                $line.ScaleFactor = $scale
                if ($null -ne $sourceStart) {
                    $line.SourceStartTime = $sourceStart.ToString('o'); $line.SourceEndTime = $sourceEnd.ToString('o')
                }
                $line.Status = 'UnsupportedRequests'
                if ($null -eq $scale -or @($group.Group | Where-Object {
                    $_.CompletenessStatus -ne 'Reconciled' -or $null -eq $_.RequestCount
                }).Count) { $line.Status = 'RequestsUnavailable' }
                elseif ($detail.GeoType -eq 'Secondary' -and $scenario -notin @('RA-GRS', 'RA-GZRS')) {
                    $line.Status = 'IneligibleSecondaryReads'
                }
                elseif ($detail.Category -eq 'Free') {
                    $line.Quantity = [decimal]0
                    foreach ($d in $group.Group) { $line.Quantity += [decimal]$d.RequestCount * $scale }
                    $line.EstimatedCost = [decimal]0; $line.Status = 'DocumentedFree'
                } elseif ($supportedConfiguration -and
                    $detail.GeoType -in @('Primary', 'Secondary') -and
                    $line.Tier -in @('Hot', 'Cool', 'Cold') -and
                    ($detail.Category -in @('Reads', 'Writes', 'AllOtherOperations') -or
                        ($PricingMode -ne 'AdlsGen2' -and $detail.Category -eq 'ListAndCreateContainer') -or
                        ($PricingMode -eq 'AdlsGen2' -and $detail.Category -in @('IterativeReads', 'IterativeWrites')))) {
                    $line.Quantity = [decimal]0
                    foreach ($d in $group.Group) {
                        if ([decimal]$d.RequestCount -lt 0) { throw 'Request counts cannot be negative.' }
                        $line.Quantity += [decimal]$d.RequestCount * $scale
                    }
                    $line.ProductName = $product
                    $line.SkuName = "$($line.Tier) $scenario"
                    $writeSku = if ($scenario -eq 'RA-GRS') { 'GRS' }
                        elseif ($scenario -eq 'RA-GZRS') { 'GZRS' }
                        else { $scenario }
                    $meterSku = if ($line.Tier -eq 'Cold' -and $scenario -in @('RA-GRS', 'RA-GZRS')) {
                        $scenario
                    } else { $writeSku }
                    $names = switch ($detail.Category) {
                        'Reads' { @("$($line.Tier) Read Operations", "$($line.Tier) ZRS Read Operations", "$($line.Tier) $scenario Read Operations") }
                        'Writes' { @("$($line.Tier) $meterSku Write Operations") }
                        'ListAndCreateContainer' { @("$writeSku List and Create Container Operations") }
                        'AllOtherOperations' { @('All Other Operations') }
                    }
                    $unit = '10K'
                    if ($PricingMode -eq 'BlobHns') {
                        if ($detail.Category -in @('ListAndCreateContainer', 'AllOtherOperations')) {
                            $line.SkuName = "Hot $scenario"
                        }
                        $names = switch ($detail.Category) {
                            'Reads' { @("$($line.Tier) $scenario Read Operations") }
                            'Writes' { @("$($line.Tier) $meterSku Write Operations") }
                            'ListAndCreateContainer' { @("Hot $writeSku Write Operations") }
                            'AllOtherOperations' { @("Hot $scenario Other Operations") }
                        }
                    } elseif ($PricingMode -eq 'AdlsGen2') {
                        if ($detail.Category -in @('IterativeReads', 'IterativeWrites', 'AllOtherOperations')) {
                            $line.SkuName = "Hot $scenario"
                        }
                        $names = switch ($detail.Category) {
                            'Reads' {
                                if ($line.Tier -eq 'Cold') { @("Cold $scenario Read Operations") }
                                else { @("$($line.Tier) Read Operations") }
                            }
                            'Writes' { @("$($line.Tier) $meterSku Write Operations") }
                            'IterativeReads' { @("Hot $writeSku Iterative Read Operations") }
                            'IterativeWrites' {
                                $unit = '100'
                                if ($scenario -eq 'ZRS') { @('Hot Iterative Write Operations') }
                                else { @("Hot $writeSku Iterative Write Operations") }
                            }
                            'AllOtherOperations' { @('Hot Other Operations') }
                        }
                    }
                    Set-RetailCost -PriceTime $priceTime -Line $line -Catalog $catalogs[$region] -MeterNames $names -Unit $unit
                }
                $lines.Add($line)
            }
            $summary = New-EstimateRecord @estimateParameters -Account $account -Scenario $scenario `
                -Type 'Scenario' -Component 'PricedSubtotal' `
                -IncludeGeoReplicationTransfer:$scenarioIncludesGeoReplicationTransfer
            $summary.NamespaceBasis = $namespaceBasis
            $summary.IsCurrentConfiguration = [string]::Equals(
                [string]$scenario, [string]$currentRedundancy,
                [System.StringComparison]::OrdinalIgnoreCase
            )
            $summary.Status = 'PartialEstimate'
            $summary.QuantityBasis = 'CurrentCapacityHeldConstantAndObservedRequestsScaledToModelMonth'
            $summary.ScaleFactor = $scale
            if ($null -ne $sourceStart) {
                $summary.SourceStartTime = $sourceStart.ToString('o')
                $summary.SourceEndTime = $sourceEnd.ToString('o')
            }
            $summary.UnpricedComponents = (@($lines | Where-Object {
                $_.Status -notin @('PlanningEstimate', 'DocumentedFree')
            } | ForEach-Object { "$($_.Component):$($_.Status)" }) -join ';')
            if (@($lines | Where-Object Status -like 'Ineligible*').Count) { $summary.Status = 'Ineligible' }
            $componentKeys = @($lines | Where-Object { $null -ne $_.EstimatedCost } | ForEach-Object {
                ConvertTo-Json -InputObject @($_.Component, $_.Tier, $_.GeoType) -Compress
            } | Sort-Object -Unique)
            $scenarioSummaries.Add([pscustomobject]@{
                Redundancy = $scenario
                Summary = $summary
                ComponentKeys = $componentKeys
            })
            foreach ($line in $lines) {
                if ($null -ne $line.EstimatedCost) {
                    if ($null -eq $summary.PricedSubtotal) { $summary.PricedSubtotal = [decimal]0 }
                    $summary.PricedSubtotal += $line.EstimatedCost
                }
                if ($line.Status -notin @('PlanningEstimate', 'DocumentedFree')) {
                    $line.Message = "Not priced: $($line.Status). No zero cost is inferred."
                    Write-Warning "$($account.StorageAccountName) $scenario $($line.Component): $($line.Message)"
                }
                $scenarioOutput.Add($line)
            }
            $summary.Message = 'Subtotal includes only priced capacity and request estimates. Excluded charges and unsupported inputs prevent a complete recurring-cost total. Catalog presence does not prove regional deployment eligibility.'
            if (-not $details.Count -and $null -eq $scale) { $summary.Message += ' No usable observed request period supplied.' }
            $scenarioOutput.Add($summary)
        }

        $currentSummary = $scenarioSummaries | Where-Object Redundancy -eq $currentRedundancy | Select-Object -First 1
        foreach ($scenarioResult in $scenarioSummaries) {
            $summary = $scenarioResult.Summary
            if (-not $currentRedundancy) {
                $summary.DeltaFromCurrentReason = 'CurrentRedundancyUnknown'
            } elseif ($null -eq $currentSummary) {
                $summary.DeltaFromCurrentReason = 'CurrentScenarioNotSelected'
            } elseif ($null -eq $currentSummary.Summary.PricedSubtotal) {
                $summary.DeltaFromCurrentReason = 'CurrentSubtotalUnavailable'
            } elseif ($null -eq $summary.PricedSubtotal) {
                $summary.DeltaFromCurrentReason = 'ScenarioSubtotalUnavailable'
            } elseif (-not $scenarioResult.ComponentKeys.Count -or -not $currentSummary.ComponentKeys.Count) {
                $summary.DeltaFromCurrentReason = 'NoPricedComponentsToCompare'
            } else {
                $differentComponents = @($scenarioResult.ComponentKeys | Where-Object {
                    $_ -notin $currentSummary.ComponentKeys
                }).Count -gt 0 -or @($currentSummary.ComponentKeys | Where-Object {
                    $_ -notin $scenarioResult.ComponentKeys
                }).Count -gt 0
                if ($differentComponents) {
                    $summary.DeltaFromCurrentReason = 'PricedComponentsDifferFromCurrent'
                } else {
                    $summary.DeltaFromCurrent = [decimal]$summary.PricedSubtotal -
                        [decimal]$currentSummary.Summary.PricedSubtotal
                }
            }
        }
        $scenarioOutput.ToArray() | Set-StorageRecordType
    }
}
