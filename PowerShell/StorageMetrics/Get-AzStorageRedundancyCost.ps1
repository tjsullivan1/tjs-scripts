#Requires -Version 7.0

function Get-AzStorageRedundancyCost {
    <#
    .SYNOPSIS
    Prices a current Blob or opt-in ADLS Gen2 footprint under four redundancy options.
    .DESCRIPTION
    Consumes objects from Get-AzStorageTransactionMetric, not overlapping totals.
    Holds current capacity constant and scales observed requests to ModelMonth.
    Fetches current public USD consumption prices independently of collection.
    Returns line items and partial scenario subtotals, never a complete invoice
    estimate. Retrieval, bandwidth, replication, feature and migration costs are
    excluded explicitly. Endpoint schedules, premium and unresolved tiers are not guessed.
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
    .EXAMPLE
    . .\PowerShell\StorageMetrics\Get-AzStorageRedundancyCost.ps1
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10'
    .EXAMPLE
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10' -PricingMode AdlsGen2
    Models the supplied HNS workload using the DFS endpoint schedule.
    .EXAMPLE
    Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10' -PricingMode BlobHns
    Models the supplied HNS workload using the Blob endpoint schedule (including NFS/SFTP).
    .OUTPUTS
    System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$Records,
        [Parameter(Mandatory)][ValidatePattern('^\d{4}-(0[1-9]|1[0-2])$')][string]$ModelMonth,
        [ValidateSet('Hot', 'Cool', 'Cold', 'Archive')][string]$LegacyTargetTier,
        [switch]$AssumeFlatNamespace,
        [ValidateSet('BlobFlat', 'BlobHns', 'AdlsGen2')][string]$PricingMode = 'BlobFlat'
    )

    $modelStart = [datetimeoffset]::ParseExact("$ModelMonth-01", 'yyyy-MM-dd',
        [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
    $modelHours = [decimal]($modelStart.AddMonths(1) - $modelStart).TotalHours
    $priceTime = [datetimeoffset]::UtcNow
    $catalogs = @{}
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

    function Get-RetailCatalog {
        param([string]$Region)
        if ($Region -notmatch '^[a-z0-9]+$') { throw "Invalid Azure region: $Region" }
        $products = switch ($PricingMode) {
            'BlobFlat' { "(productName eq 'Blob Storage' or productName eq 'General Block Blob v2')" }
            'BlobHns' { "(productName eq 'General Block Blob v2 Hierarchical Namespace' or productName eq 'Azure Data Lake Storage Gen2 Hierarchical Namespace')" }
            'AdlsGen2' { "productName eq 'Azure Data Lake Storage Gen2 Hierarchical Namespace'" }
        }
        $filter = "serviceName eq 'Storage' and armRegionName eq '$Region' and priceType eq 'Consumption' and $products"
        $uri = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview&%24filter=' +
            [uri]::EscapeDataString($filter)
        $seen = [System.Collections.Generic.HashSet[string]]::new()
        $items = [System.Collections.Generic.List[object]]::new()
        while ($uri) {
            $link = [uri]$uri
            if ($link.Scheme -ne 'https' -or $link.Host -ne 'prices.azure.com' -or
                $link.AbsolutePath -ne '/api/retail/prices' -or -not $link.IsDefaultPort -or $link.UserInfo) {
                throw 'Retail catalog returned an unexpected pagination URL.'
            }
            if (-not $seen.Add($uri) -or $seen.Count -gt 100) { throw 'Retail pagination is cyclic or exceeds 100 pages.' }
            $page = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
            if ($null -eq $page.Items) { throw 'Retail catalog response has no Items.' }
            foreach ($item in $page.Items) { $items.Add($item) }
            $uri = $page.NextPageLink
        }
        $items.ToArray()
    }

    function New-EstimateRecord {
        param([object]$Account, [string]$Scenario, [string]$Type, [string]$Component)
        [pscustomobject][ordered]@{
            RecordType = $Type; ResourceId = $Account.ResourceId
            StorageAccountName = $Account.StorageAccountName; Location = $Account.Location
            CurrentAccountKind = $Account.AccountKind; CurrentSkuName = $Account.SkuName
            TargetAccountKind = 'StorageV2'; Redundancy = $Scenario; ModelMonth = $ModelMonth
            Component = $Component; Tier = $null; Quantity = $null; QuantityUnit = $null
            QuantityBasis = $null; SourceStartTime = $null; SourceEndTime = $null
            CapacitySampleTimeUtc = $null; ScaleFactor = $null
            NamespaceBasis = $null
            PricingMode = $PricingMode
            BillabilityAssumption = if ($PricingMode -eq 'AdlsGen2') {
                'Observed requests approximate operations; no 4 MiB read/write expansion or recursive/iterative fan-out inferred.'
            } else { 'Observed requests approximate operations; endpoint schedule explicitly selected, not inferred from HNS.' }
            LegacyTargetTierAssumption = $LegacyTargetTier
            Currency = 'USD'; ProductName = $null; SkuName = $null; MeterName = $null
            MeterId = $null; RateUnit = $null; RateBandsJson = $null; PricesObservedAtUtc = $priceTime.ToString('o')
            EstimatedCost = $null; PricedSubtotal = $null; TotalRecurringCost = $null
            OneTimeCost = $null; Status = $null; Message = $null
            UnpricedComponents = $null
            ExcludedCharges = 'Retrieval;Bandwidth;GeoReplicationTransfer;EarlyDeletion;Features;Migration;Discounts;Taxes'
        }
    }

    function Set-RetailCost {
        param([object]$Line, [object[]]$Catalog, [string[]]$MeterNames, [string]$Unit)
        $Line.RateUnit = $Unit
        $catalogMatches = @($Catalog | Where-Object {
            $_.serviceName -eq 'Storage' -and $_.armRegionName -eq $Line.Location -and
            $_.productName -eq $Line.ProductName -and $_.skuName -eq $Line.SkuName -and
            $_.meterName -in $MeterNames -and $_.unitOfMeasure -eq $Unit -and
            $_.currencyCode -eq 'USD' -and $_.type -eq 'Consumption' -and
            [datetimeoffset]$_.effectiveStartDate -le $priceTime
        })
        if (-not $catalogMatches.Count) { $Line.Status = 'PriceUnavailable'; return }
        if (@($catalogMatches | Group-Object meterId, meterName).Count -ne 1) {
            $Line.Status = 'AmbiguousPrice'; return
        }
        $bands = @(
            foreach ($group in ($catalogMatches | Group-Object tierMinimumUnits)) {
                $latest = @($group.Group | Sort-Object { [datetimeoffset]$_.effectiveStartDate } -Descending)
                $sameDate = @($latest | Where-Object effectiveStartDate -eq $latest[0].effectiveStartDate)
                if ($sameDate.Count -ne 1) { $Line.Status = 'AmbiguousPrice'; return }
                $latest[0]
            }
        ) | Sort-Object { [decimal]$_.tierMinimumUnits }
        if (-not $bands.Count -or [decimal]$bands[0].tierMinimumUnits -ne 0) {
            $Line.Status = 'PriceUnavailable'; return
        }
        $cost = [decimal]0
        for ($i = 0; $i -lt $bands.Count; $i++) {
            $band = $bands[$i]
            if ($null -eq $band.retailPrice -or [decimal]$band.retailPrice -lt 0 -or
                [decimal]$band.tierMinimumUnits -lt 0) { throw 'Retail catalog contains an invalid rate band.' }
            $quantity = $Line.Quantity
            if ($Unit -eq '10K') { $quantity /= [decimal]10000 }
            elseif ($Unit -eq '100') { $quantity /= [decimal]100 }
            $upper = if ($i + 1 -lt $bands.Count) { [decimal]$bands[$i + 1].tierMinimumUnits } else { $quantity }
            $used = [math]::Max([decimal]0, [math]::Min($quantity, $upper) - [decimal]$band.tierMinimumUnits)
            $cost += $used * [decimal]$band.retailPrice
        }
        $Line.EstimatedCost = $cost
        $Line.MeterName = $bands[0].meterName
        $Line.MeterId = $bands[0].meterId
        $Line.RateBandsJson = ConvertTo-Json -InputObject @($bands | Select-Object tierMinimumUnits, retailPrice, effectiveStartDate, isPrimaryMeterRegion) -Compress
        $Line.Status = 'PlanningEstimate'
    }

    foreach ($accountGroup in ($snapshots | Group-Object ResourceId)) {
        $account = $accountGroup.Group[0]
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
        if (-not $catalogs.ContainsKey($region)) { $catalogs[$region] = @(Get-RetailCatalog -Region $region) }
        foreach ($scenario in @('ZRS', 'GRS', 'GZRS', 'RA-GRS')) {
            $product = switch ($PricingMode) {
                'BlobFlat' { if ($scenario -in @('ZRS', 'GZRS')) { 'General Block Blob v2' } else { 'Blob Storage' } }
                'BlobHns' { 'General Block Blob v2 Hierarchical Namespace' }
                'AdlsGen2' { 'Azure Data Lake Storage Gen2 Hierarchical Namespace' }
            }
            $lines = [System.Collections.Generic.List[object]]::new()
            foreach ($capacityGroup in ($accountGroup.Group | Group-Object Tier)) {
                $capacity = $capacityGroup.Group[0]
                $line = New-EstimateRecord $account $scenario 'Estimate' 'Capacity'
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
                    } elseif ($line.Tier -eq 'Archive' -and $scenario -in @('ZRS', 'GZRS')) {
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
                        Set-RetailCost $line $catalogs[$region] @("$($line.Tier) $scenario Data Stored") '1 GB/Month'
                    }
                }
                $lines.Add($line)
            }
            if ($hnsMode) {
                $line = New-EstimateRecord $account $scenario 'Estimate' 'HnsIndexCapacity'
                $line.NamespaceBasis = $namespaceBasis
                $line.Tier = 'Hot'
                $line.QuantityUnit = 'GiBMonth'
                $line.QuantityBasis = 'CurrentIndexCapacityHeldConstantForModelMonthSeparateFromBlobCapacity'
                $line.ProductName = 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
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
                            Set-RetailCost $line $catalogs[$region] @("Hot $scenario Index") '1 GB/Month'
                        }
                    }
                }
                $lines.Add($line)
            }
            foreach ($group in ($details | Group-Object Tier, Category, GeoType)) {
                $detail = $group.Group[0]
                $line = New-EstimateRecord $account $scenario 'Estimate' $detail.Category
                $line.NamespaceBasis = $namespaceBasis
                $line.Tier = $detail.Tier
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
                elseif ($detail.GeoType -eq 'Secondary' -and $scenario -ne 'RA-GRS') { $line.Status = 'IneligibleSecondaryReads' }
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
                    $writeSku = if ($scenario -eq 'RA-GRS') { 'GRS' } else { $scenario }
                    $names = switch ($detail.Category) {
                        'Reads' { @("$($line.Tier) Read Operations", "$($line.Tier) ZRS Read Operations", "$($line.Tier) $scenario Read Operations") }
                        'Writes' { @("$($line.Tier) $writeSku Write Operations") }
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
                            'Writes' { @("$($line.Tier) $scenario Write Operations") }
                            'ListAndCreateContainer' { @("Hot $scenario Write Operations") }
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
                            'Writes' {
                                $meterSku = if ($line.Tier -eq 'Cold') { $scenario } else { $writeSku }
                                @("$($line.Tier) $meterSku Write Operations")
                            }
                            'IterativeReads' { @("Hot $writeSku Iterative Read Operations") }
                            'IterativeWrites' {
                                $unit = '100'
                                if ($scenario -eq 'ZRS') { @('Hot Iterative Write Operations') }
                                else { @("Hot $writeSku Iterative Write Operations") }
                            }
                            'AllOtherOperations' { @('Hot Other Operations') }
                        }
                    }
                    Set-RetailCost $line $catalogs[$region] $names $unit
                }
                $lines.Add($line)
            }
            $summary = New-EstimateRecord $account $scenario 'Scenario' 'PricedSubtotal'
            $summary.NamespaceBasis = $namespaceBasis
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
            foreach ($line in $lines) {
                if ($null -ne $line.EstimatedCost) {
                    if ($null -eq $summary.PricedSubtotal) { $summary.PricedSubtotal = [decimal]0 }
                    $summary.PricedSubtotal += $line.EstimatedCost
                }
                if ($line.Status -notin @('PlanningEstimate', 'DocumentedFree')) {
                    $line.Message = "Not priced: $($line.Status). No zero cost is inferred."
                    Write-Warning "$($account.StorageAccountName) $scenario $($line.Component): $($line.Message)"
                }
                $line
            }
            $summary.Message = 'Subtotal includes only priced capacity and request estimates. Excluded charges and unsupported inputs prevent a complete recurring-cost total. Catalog presence does not prove regional deployment eligibility.'
            if (-not $details.Count -and $null -eq $scale) { $summary.Message += ' No usable observed request period supplied.' }
            $summary
        }
    }
}
