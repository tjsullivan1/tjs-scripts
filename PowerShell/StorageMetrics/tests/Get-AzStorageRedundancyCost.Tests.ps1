Describe 'Public storage redundancy planning estimate' {
    BeforeEach {
        $script:path = "$PSScriptRoot\..\Get-AzStorageRedundancyCost.ps1"
        if (Test-Path $script:path) { . $script:path }
        $script:records = @(
            [pscustomobject]@{
                RecordType = 'CurrentCapacity'; ResourceId = '/accounts/example'
                StorageAccountName = 'example'; Location = 'eastus'
                AccountKind = 'StorageV2'; SkuName = 'Standard_RAGRS'
                IsHnsEnabled = $false; Tier = 'Hot'; BlobType = 'BlockBlob'
                CurrentUsedGiB = 2; CapacityStatus = 'LatestReconciledSample'
                CapacitySampleTimeUtc = '2026-10-01T00:00:00Z'
            },
            [pscustomobject]@{
                RecordType = 'AccountTotal'; ResourceId = '/accounts/example'
                StartTime = '2026-09-01T00:00:00Z'; EndTime = '2026-09-11T00:00:00Z'
                CompletenessStatus = 'Reconciled'
                RequestCount = 10000
            },
            [pscustomobject]@{
                RecordType = 'Detail'; ResourceId = '/accounts/example'
                StartTime = '2026-09-01T00:00:00Z'; EndTime = '2026-09-11T00:00:00Z'
                Category = 'Reads'; Tier = 'Hot'; GeoType = 'Primary'
                RequestCount = 10000; CompletenessStatus = 'Reconciled'
            }
        )
        $script:catalog = @(
            foreach ($sku in @('ZRS', 'GRS', 'GZRS', 'RA-GRS')) {
                $product = if ($sku -in @('ZRS', 'GZRS')) { 'General Block Blob v2' } else { 'Blob Storage' }
                foreach ($band in @(0, 1)) {
                    [pscustomobject]@{
                        serviceName = 'Storage'; productName = $product; skuName = "Hot $sku"
                        meterName = "Hot $sku Data Stored"; meterId = "capacity-$sku"
                        armRegionName = 'eastus'; currencyCode = 'USD'; type = 'Consumption'
                        isPrimaryMeterRegion = $true; unitOfMeasure = '1 GB/Month'
                        tierMinimumUnits = $band; retailPrice = $(if ($band) { 0.01 } else { 0.02 })
                        effectiveStartDate = '2020-01-01T00:00:00Z'
                    }
                }
                [pscustomobject]@{
                    serviceName = 'Storage'; productName = $product; skuName = "Hot $sku"
                    meterName = $(if ($sku -in @('ZRS', 'GZRS')) { 'Hot ZRS Read Operations' } else { 'Hot Read Operations' })
                    meterId = "reads-$sku"; armRegionName = 'eastus'; currencyCode = 'USD'
                    type = 'Consumption'; isPrimaryMeterRegion = $true; unitOfMeasure = '10K'
                    tierMinimumUnits = 0; retailPrice = 0.004
                    effectiveStartDate = '2020-01-01T00:00:00Z'
                }
            }
        )
        $script:hnsCatalog = @(
            foreach ($sku in @('ZRS', 'GRS', 'GZRS', 'RA-GRS')) {
                foreach ($product in @('Azure Data Lake Storage Gen2 Hierarchical Namespace', 'General Block Blob v2 Hierarchical Namespace')) {
                    $writeSku = if ($sku -eq 'RA-GRS' -and $product -like 'Azure*') { 'GRS' } else { $sku }
                    $iterSku = if ($sku -eq 'RA-GRS') { 'GRS' } else { $sku }
                    $meters = @{
                        "Hot $sku Data Stored" = @('1 GB/Month', 0.02)
                        "Cool $sku Data Stored" = @('1 GB/Month', 0.01)
                        "Archive $sku Data Stored" = @('1 GB/Month', 0.001)
                        "Hot $writeSku Write Operations" = @('10K', 0.05)
                        "Cool $writeSku Write Operations" = @('10K', 0.1)
                        "Cold $sku Read Operations" = @('10K', 0.03)
                        "Cold $sku Write Operations" = @('10K', 0.18)
                    }
                    if ($product -like 'Azure*') {
                        $meters['Hot Read Operations'] = @('10K', 0.004)
                        $meters["Hot $sku Index"] = @('1 GB/Month', 0.01)
                        $meters["Hot $iterSku Iterative Read Operations"] = @('10K', 0.05)
                        $iterWrite = if ($sku -eq 'ZRS') { 'Hot Iterative Write Operations' } else { "Hot $iterSku Iterative Write Operations" }
                        $meters[$iterWrite] = @('100', 0.07)
                        $meters['Hot Other Operations'] = @('10K', 0.004)
                    } else {
                        $meters["Hot $sku Read Operations"] = @('10K', 0.008)
                        $meters["Hot $sku Other Operations"] = @('10K', 0.006)
                    }
                    foreach ($name in $meters.Keys) {
                        $tier = ($name -split ' ')[0]
                        [pscustomobject]@{
                            serviceName = 'Storage'; productName = $product; skuName = "$tier $sku"
                            meterName = $name; meterId = "$product-$sku-$name"; armRegionName = 'eastus'
                            currencyCode = 'USD'; type = 'Consumption'; isPrimaryMeterRegion = $false
                            unitOfMeasure = $meters[$name][0]; tierMinimumUnits = 0
                            retailPrice = $meters[$name][1]; effectiveStartDate = '2020-01-01T00:00:00Z'
                        }
                    }
                }
            }
        )
        Mock Invoke-RestMethod { [pscustomobject]@{ Items = $script:catalog; NextPageLink = $null } }
    }

    It 'prices identical current capacity independently using graduated public rate bands' {
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09')
        $capacity = @($rows | Where-Object Component -eq 'Capacity')
        $capacity.Count | Should Be 4
        @($capacity | Where-Object { $_.Quantity -ne 2 }).Count | Should Be 0
        @($capacity | Where-Object { $_.EstimatedCost -ne [decimal]0.03 }).Count | Should Be 0
        @($rows | Where-Object RecordType -eq 'Scenario').Count | Should Be 4
        Assert-MockCalled Invoke-RestMethod -Times 1 -Scope It
    }

    It 'scales a ten-day request window to a 30-day month without claiming exact billability' {
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09')
        $reads = @($rows | Where-Object Component -eq 'Reads')
        $reads[0].Quantity | Should Be 30000
        $reads[0].ScaleFactor | Should Be 3
        $reads[0].EstimatedCost | Should Be ([decimal]0.012)
        $reads[0].QuantityUnit | Should Be 'EstimatedOperations'
        $reads[0].QuantityBasis | Should Be 'ObservedRequestsScaledToModelMonthNotBillableCounts'
        $summary = $rows | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1
        $summary.PricedSubtotal | Should Be ([decimal]0.042)
        $summary.Status | Should Be 'PartialEstimate'
        ($null -eq $summary.TotalRecurringCost) | Should Be $true
        ($null -eq $summary.OneTimeCost) | Should Be $true
        $summary.ExcludedCharges | Should Match 'GeoReplicationTransfer'
    }

    It 'scales by actual model-month duration and ignores overlapping collector totals' {
        $extra = $script:records[0].PSObject.Copy()
        $extra.RecordType = 'CurrentCapacityAccountTotal'
        $extra.CurrentUsedGiB = 100
        $rows = @(Get-AzStorageRedundancyCost -Records (@($script:records) + @($extra)) -ModelMonth '2026-10')
        @($rows | Where-Object Component -eq 'Capacity').Count | Should Be 4
        ($rows | Where-Object Component -eq 'Reads' | Select-Object -First 1).Quantity | Should Be 31000
    }

    It 'rejects duplicate current snapshots rather than doubling the footprint' {
        { Get-AzStorageRedundancyCost -Records (@($script:records) + @($script:records[0])) -ModelMonth '2026-09' } | Should Throw 'Duplicate current capacity'
    }

    It 'does not infer usable prices from a missing or ambiguous catalog' {
        $script:catalog = @()
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        @($rows | Where-Object { $_.RecordType -eq 'Estimate' -and $null -ne $_.EstimatedCost }).Count | Should Be 0
        $script:catalog = @([pscustomobject]@{
            serviceName = 'Storage'; productName = 'General Block Blob v2'; skuName = 'Hot ZRS'
            meterName = 'Hot ZRS Data Stored'; meterId = 'a'; armRegionName = 'eastus'
            currencyCode = 'USD'; type = 'Consumption'; isPrimaryMeterRegion = $true
            unitOfMeasure = '1 GB/Month'; tierMinimumUnits = 0; retailPrice = 0.02
            effectiveStartDate = '2020-01-01T00:00:00Z'
        })
        $other = $script:catalog[0].PSObject.Copy()
        $other.meterId = 'b'
        $script:catalog += $other
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object { $_.Component -eq 'Capacity' -and $_.Redundancy -eq 'ZRS' }).Status | Should Be 'AmbiguousPrice'
    }

    It 'blocks HNS and unavailable capacity instead of guessing a pricing schedule' {
        $script:records[0].IsHnsEnabled = $true
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1).Status | Should Be 'UnsupportedConfiguration'
        $script:records[0].IsHnsEnabled = $false
        $script:records[0].CurrentUsedGiB = $null
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1).Status | Should Be 'CapacityUnavailable'
    }

    It 'requires an explicit modern tier assumption for GPv1 and exposes it in output' {
        $script:records[0].AccountKind = 'Storage'
        $script:records[0].Tier = 'Untiered'
        $script:records[2].Tier = 'Untiered'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1).Status | Should Be 'TierUnresolved'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -LegacyTargetTier Hot)
        ($rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1).QuantityBasis | Should Be 'CurrentGPv1CapacityHeldConstantInAssumedGPv2Tier'
        ($rows | Where-Object Component -eq 'Reads' | Select-Object -First 1).EstimatedCost | Should Be ([decimal]0.012)
    }

    It 'flags Archive and secondary-read requirements incompatible with target options' {
        $script:records[0].Tier = 'Archive'
        $script:records[2].GeoType = 'Secondary'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        @($rows | Where-Object Status -eq 'IneligibleArchive').Count | Should Be 2
        @($rows | Where-Object Status -eq 'IneligibleSecondaryReads').Count | Should Be 3
        @($rows | Where-Object { $_.RecordType -eq 'Scenario' -and $_.Status -eq 'Ineligible' }).Count | Should Be 3
    }

    It 'preserves documented free requests but never prices unknown APIs as paid other operations' {
        $script:records[2].Category = 'Free'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09')
        ($rows | Where-Object Component -eq 'Free' | Select-Object -First 1).EstimatedCost | Should Be 0
        $script:records[2].Category = 'Unmapped'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'Unmapped' | Select-Object -First 1).Status | Should Be 'UnsupportedRequests'
    }

    It 'rejects mismatched request detail coverage instead of extrapolating unrelated requests' {
        $script:records[2].EndTime = '2026-09-12T00:00:00Z'
        { Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' } | Should Throw 'Detail period'
    }

    It 'surfaces catalog failures and rejects non-public pagination destinations' {
        Mock Invoke-RestMethod { throw 'Network unavailable' }
        { Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' } | Should Throw 'Network unavailable'
        Mock Invoke-RestMethod { [pscustomobject]@{ Items = @(); NextPageLink = 'https://example.com/api/retail/prices' } }
        { Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' } | Should Throw 'unexpected pagination'
    }

    It 'supports strict-mode CSV JSON exports with a consistent mixed-record schema' {
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09')
            $rows | Export-Csv "$TestDrive\estimate.csv" -NoTypeInformation
            $csv = Import-Csv "$TestDrive\estimate.csv"
            ($csv | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1).PricedSubtotal | Should Be '0.042'
            $json = ConvertTo-Json -InputObject $rows -Depth 5 | ConvertFrom-Json
            @($json).Count | Should Be 12
        } finally { Set-StrictMode -Off }
    }

    It 'requires an explicit flat namespace assumption when the ARM property is unavailable' {
        $script:records[0].IsHnsEnabled = $null
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1).PricedSubtotal | Should BeNullOrEmpty
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -AssumeFlatNamespace)
        ($rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1).NamespaceBasis | Should Be 'AssumedFlatWhenUnspecified'
        ($rows | Where-Object Component -eq 'Reads' | Select-Object -First 1).EstimatedCost | Should Be ([decimal]0.012)
    }

    It 'retains regional retail reference meters for non-primary operation prices' {
        foreach ($rate in $script:catalog) { if ($rate.unitOfMeasure -eq '10K') { $rate.isPrimaryMeterRegion = $false } }
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'Reads' | Select-Object -First 1).EstimatedCost | Should Be ([decimal]0.012)
    }

    It 'rejects incomplete detail exports instead of pricing an understated transaction total' {
        $script:records[1].RequestCount = 20000
        { Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' } | Should Throw 'Detail counts'
    }

    It 'applies capacity bands to combined blob types within one account tier' {
        $append = $script:records[0].PSObject.Copy()
        $append.BlobType = 'AppendBlob'
        $rows = @(Get-AzStorageRedundancyCost -Records (@($script:records) + @($append)) -ModelMonth '2026-09')
        $capacity = @($rows | Where-Object Component -eq 'Capacity')
        $capacity.Count | Should Be 4
        $capacity[0].Quantity | Should Be 4
        $capacity[0].EstimatedCost | Should Be ([decimal]0.05)
    }

    It 'does not silently omit collector account failures from a multi-account estimate' {
        $failure = [pscustomobject]@{ RecordType = 'Error'; ResourceId = '/accounts/failed'; Message = 'Denied' }
        { Get-AzStorageRedundancyCost -Records (@($script:records) + @($failure)) -ModelMonth '2026-09' } | Should Throw 'collector failures'
    }

    It 'opts into DFS HNS capacity and reads without borrowing flat or Blob endpoint prices' {
        $script:records[0].IsHnsEnabled = $true
        $hns = @(
            foreach ($rate in $script:catalog) {
                $copy = $rate.PSObject.Copy()
                $copy.productName = 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
                if ($copy.unitOfMeasure -eq '10K') { $copy.meterName = 'Hot Read Operations'; $copy.retailPrice = 0.02 }
                $copy
            }
        )
        $script:catalog += $hns
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-10' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        @($rows | Where-Object { $_.PricingMode -ne 'AdlsGen2' }).Count | Should Be 0
        @($rows | Where-Object { $_.NamespaceBasis -ne 'CurrentConfigurationHns' }).Count | Should Be 0
        $capacity = $rows | Where-Object Component -eq 'Capacity' | Select-Object -First 1
        $capacity.EstimatedCost | Should Be ([decimal]0.03)
        $capacity.ProductName | Should Be 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
        $reads = $rows | Where-Object Component -eq 'Reads' | Select-Object -First 1
        $reads.Quantity | Should Be 31000
        $reads.EstimatedCost | Should Be ([decimal]0.062)
        $reads.BillabilityAssumption | Should Match '4 MiB'
        Assert-MockCalled Invoke-RestMethod -Scope It -Times 1 -ParameterFilter {
            [uri]::UnescapeDataString($Uri) -match "productName eq 'Azure Data Lake Storage Gen2 Hierarchical Namespace'"
        }
    }

    It 'prices DFS iterative writes per hundred and iterative reads per ten thousand on Hot meters' {
        $script:records[0].IsHnsEnabled = $true
        $script:records[2].Category = 'IterativeWrites'
        $script:records[2].Tier = 'Cool'
        $script:catalog += $script:hnsCatalog
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        $writes = @($rows | Where-Object Component -eq 'IterativeWrites')
        @($writes | Where-Object { $_.EstimatedCost -ne [decimal]21 }).Count | Should Be 0
        $writes[0].Tier | Should Be 'Cool'
        $writes[0].SkuName | Should Be 'Hot ZRS'
        $writes[0].RateUnit | Should Be '100'
        $script:records[2].Category = 'IterativeReads'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        @($rows | Where-Object { $_.Component -eq 'IterativeReads' -and $_.EstimatedCost -ne [decimal]0.15 }).Count | Should Be 0
    }

    It 'uses separate Blob HNS read write other and Hot list schedules rather than DFS schedules' {
        $script:records[0].IsHnsEnabled = $true
        $script:catalog += $script:hnsCatalog
        foreach ($case in @(@('Reads', 'Hot', 0.024), @('Writes', 'Cool', 0.3),
                @('AllOtherOperations', 'Cool', 0.018), @('ListAndCreateContainer', 'Cool', 0.15))) {
            $script:records[2].Category = $case[0]; $script:records[2].Tier = $case[1]
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode BlobHns -WarningAction SilentlyContinue)
            $operations = @($rows | Where-Object Component -eq $case[0])
            @($operations | Where-Object { $_.EstimatedCost -ne [decimal]$case[2] }).Count | Should Be 0
            $operations[3].ProductName | Should Be 'General Block Blob v2 Hierarchical Namespace'
        }
    }

    It 'prices index once per account separately at Hot rates for either HNS endpoint mode' {
        $script:records[0].IsHnsEnabled = $true
        $cool = $script:records[0].PSObject.Copy(); $cool.Tier = 'Cool'
        $index = $script:records[0].PSObject.Copy()
        $index.RecordType = 'CurrentIndexCapacity'; $index.Tier = $null; $index.BlobType = $null
        $index.CurrentUsedGiB = 3; $index.CapacityStatus = 'LatestSample'
        $overlap = $index.PSObject.Copy(); $overlap.RecordType = 'IndexCapacity'
        $overlap.CurrentUsedGiB = 999
        $script:records += @($cool, $index, $overlap)
        $script:catalog += $script:hnsCatalog
        foreach ($mode in @('AdlsGen2', 'BlobHns')) {
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode $mode)
            $indexes = @($rows | Where-Object Component -eq 'HnsIndexCapacity')
            $indexes.Count | Should Be 4
            @($indexes | Where-Object { $_.Quantity -ne 3 -or $_.EstimatedCost -ne [decimal]0.03 }).Count | Should Be 0
            $indexes[0].Tier | Should Be 'Hot'
            $indexes[0].ProductName | Should Be 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
            @($rows | Where-Object { $_.Component -eq 'Capacity' -and $_.Quantity -ne 2 }).Count | Should Be 0
            ($rows | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1).PricedSubtotal |
                Should Be $(if ($mode -eq 'AdlsGen2') { [decimal]0.102 } else { [decimal]0.114 })
        }
    }

    It 'distinguishes missing unavailable and explicitly measured zero HNS index capacity' {
        $script:records[0].IsHnsEnabled = $true
        $script:catalog += $script:hnsCatalog
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        $missing = $rows | Where-Object Component -eq 'HnsIndexCapacity' | Select-Object -First 1
        $missing.Status | Should Be 'CapacityUnavailable'
        ($null -eq $missing.Quantity) | Should Be $true
        ($null -eq $missing.EstimatedCost) | Should Be $true
        ($rows | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1).UnpricedComponents | Should Match 'HnsIndexCapacity:CapacityUnavailable'
        $index = $script:records[0].PSObject.Copy()
        $index.RecordType = 'CurrentIndexCapacity'; $index.CurrentUsedGiB = $null
        $index.CapacityStatus = 'Unavailable'
        $script:records += $index
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        ($rows | Where-Object Component -eq 'HnsIndexCapacity' | Select-Object -First 1).Status | Should Be 'CapacityUnavailable'
        $index.CurrentUsedGiB = 0; $index.CapacityStatus = 'LatestSample'
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2)
        $zero = $rows | Where-Object Component -eq 'HnsIndexCapacity' | Select-Object -First 1
        $zero.Quantity | Should Be 0
        $zero.EstimatedCost | Should Be 0
        $zero.Status | Should Be 'PlanningEstimate'
    }

    It 'rejects duplicate and negative HNS index snapshots rather than guessing or double charging' {
        $script:records[0].IsHnsEnabled = $true
        $index = $script:records[0].PSObject.Copy()
        $index.RecordType = 'CurrentIndexCapacity'; $index.CapacityStatus = 'LatestSample'
        { Get-AzStorageRedundancyCost -Records ($script:records + @($index, $index)) -ModelMonth '2026-09' -PricingMode AdlsGen2 } |
            Should Throw 'Duplicate current index'
        $index.CurrentUsedGiB = -1
        { Get-AzStorageRedundancyCost -Records ($script:records + @($index)) -ModelMonth '2026-09' -PricingMode AdlsGen2 } |
            Should Throw 'Index capacity cannot be negative'
    }

    It 'requires known Standard StorageV2 HNS configuration without overriding flat or unknown namespaces' {
        $script:catalog += $script:hnsCatalog
        foreach ($mode in @('BlobHns', 'AdlsGen2')) {
            foreach ($hns in @($false, $null)) {
                $script:records[0].IsHnsEnabled = $hns
                $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode $mode -AssumeFlatNamespace -WarningAction SilentlyContinue)
                @($rows | Where-Object { $null -ne $_.EstimatedCost -or $null -ne $_.PricedSubtotal }).Count | Should Be 0
            }
            $script:records[0].IsHnsEnabled = $true
            foreach ($case in @(@('Storage', 'Standard_RAGRS'), @('StorageV2', 'Premium_LRS'))) {
                $script:records[0].AccountKind = $case[0]; $script:records[0].SkuName = $case[1]
                $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode $mode -WarningAction SilentlyContinue)
                @($rows | Where-Object { $null -ne $_.EstimatedCost -or $null -ne $_.PricedSubtotal }).Count | Should Be 0
            }
            $script:records[0].AccountKind = 'StorageV2'; $script:records[0].SkuName = 'Standard_RAGRS'
        }
    }

    It 'does not substitute endpoint products missing units or ambiguous iterative meter identities' {
        $script:records[0].IsHnsEnabled = $true; $script:records[2].Category = 'IterativeWrites'
        $script:catalog += $script:hnsCatalog
        $script:catalog = @($script:catalog | Where-Object { $_.productName -ne 'Azure Data Lake Storage Gen2 Hierarchical Namespace' })
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        @($rows | Where-Object { $null -ne $_.EstimatedCost }).Count | Should Be 0
        $script:catalog = @($script:hnsCatalog | ForEach-Object { $_.PSObject.Copy() })
        foreach ($rate in $script:catalog) {
            if ($rate.unitOfMeasure -eq '100') { $rate.unitOfMeasure = '10K' }
        }
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        @($rows | Where-Object { $_.Component -eq 'IterativeWrites' -and $_.Status -eq 'PriceUnavailable' }).Count | Should Be 4
        $script:catalog = @($script:hnsCatalog)
        $duplicate = ($script:hnsCatalog | Where-Object { $_.skuName -eq 'Hot ZRS' -and $_.unitOfMeasure -eq '100' } | Select-Object -First 1).PSObject.Copy()
        $duplicate.meterId = 'ambiguous-iterative'
        $script:catalog += $duplicate
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
        ($rows | Where-Object { $_.Component -eq 'IterativeWrites' -and $_.Redundancy -eq 'ZRS' }).Status | Should Be 'AmbiguousPrice'
    }

    It 'requires index catalog evidence even for measured zero and never borrows data capacity prices' {
        $script:records[0].IsHnsEnabled = $true
        $index = $script:records[0].PSObject.Copy()
        $index.RecordType = 'CurrentIndexCapacity'; $index.CapacityStatus = 'LatestSample'; $index.CurrentUsedGiB = 0
        $script:records += $index
        $script:catalog = @($script:hnsCatalog | Where-Object meterName -notlike '* Index')
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode BlobHns -WarningAction SilentlyContinue)
        $unpriced = $rows | Where-Object Component -eq 'HnsIndexCapacity' | Select-Object -First 1
        $unpriced.Status | Should Be 'PriceUnavailable'
        ($null -eq $unpriced.EstimatedCost) | Should Be $true
        $script:catalog = @($script:hnsCatalog)
        $duplicate = ($script:hnsCatalog | Where-Object meterName -eq 'Hot ZRS Index' | Select-Object -First 1).PSObject.Copy()
        $duplicate.meterId = 'ambiguous-index'; $script:catalog += $duplicate
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode BlobHns -WarningAction SilentlyContinue)
        ($rows | Where-Object { $_.Component -eq 'HnsIndexCapacity' -and $_.Redundancy -eq 'ZRS' }).Status | Should Be 'AmbiguousPrice'
    }

    It 'retains free unknown Archive secondary and endpoint-specific request gates in HNS modes' {
        $script:records[0].IsHnsEnabled = $true; $script:records[0].Tier = 'Archive'
        $script:records[2].GeoType = 'Secondary'
        $script:catalog += $script:hnsCatalog
        foreach ($mode in @('AdlsGen2', 'BlobHns')) {
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode $mode -WarningAction SilentlyContinue)
            @($rows | Where-Object Status -eq 'IneligibleArchive').Count | Should Be 2
            @($rows | Where-Object Status -eq 'IneligibleSecondaryReads').Count | Should Be 3
            ($rows | Where-Object { $_.Component -eq 'Reads' -and $_.Redundancy -eq 'RA-GRS' }).Status | Should Be 'PlanningEstimate'
            $script:records[2].GeoType = 'Primary'
            foreach ($category in @('Free', 'Unmapped', $(if ($mode -eq 'AdlsGen2') { 'ListAndCreateContainer' } else { 'IterativeWrites' }))) {
                $script:records[2].Category = $category
                $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode $mode -WarningAction SilentlyContinue)
                ($rows | Where-Object Component -eq $category | Select-Object -First 1).Status |
                    Should Be $(if ($category -eq 'Free') { 'DocumentedFree' } else { 'UnsupportedRequests' })
            }
            $script:records[2].Category = 'Reads'; $script:records[2].GeoType = 'Secondary'
        }
    }

    It 'exports HNS mode rate units assumptions and month consistently in strict CSV and JSON' {
        $script:records[0].IsHnsEnabled = $true; $script:records[2].Category = 'IterativeWrites'
        $script:catalog += $script:hnsCatalog
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-10' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
            $rows | Export-Csv "$TestDrive\adls.csv" -NoTypeInformation
            $csv = @(Import-Csv "$TestDrive\adls.csv")
            $json = @(ConvertTo-Json -InputObject $rows -Depth 6 | ConvertFrom-Json)
            foreach ($export in @(@{ Rows = $csv }, @{ Rows = $json })) {
                @($export.Rows | Where-Object { $_.PricingMode -ne 'AdlsGen2' -or $_.ModelMonth -ne '2026-10' -or -not $_.BillabilityAssumption }).Count | Should Be 0
                ($export.Rows | Where-Object Component -eq 'IterativeWrites' | Select-Object -First 1).Quantity | Should Be 31000
                ($export.Rows | Where-Object Component -eq 'IterativeWrites' | Select-Object -First 1).RateUnit | Should Be '100'
            }
            $json.Count | Should Be 16
            ($null -eq ($json | Where-Object Component -eq 'HnsIndexCapacity' | Select-Object -First 1).EstimatedCost) | Should Be $true
            ($null -eq ($json | Where-Object RecordType -eq 'Scenario' | Select-Object -First 1).TotalRecurringCost) | Should Be $true
        } finally { Set-StrictMode -Off }
    }

    It 'selects Cold RA-GRS DFS operation identities instead of Hot Cool GRS aliases' {
        $script:records[0].IsHnsEnabled = $true
        $script:records[2].Tier = 'Cold'
        $script:catalog += $script:hnsCatalog
        foreach ($case in @(@('Reads', 0.09), @('Writes', 0.54))) {
            $script:records[2].Category = $case[0]
            $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -PricingMode AdlsGen2 -WarningAction SilentlyContinue)
            $operations = @($rows | Where-Object Component -eq $case[0])
            @($operations | Where-Object { $_.EstimatedCost -ne [decimal]$case[1] }).Count | Should Be 0
            $operations[3].MeterName | Should Be $(if ($case[0] -eq 'Reads') { 'Cold RA-GRS Read Operations' } else { 'Cold RA-GRS Write Operations' })
        }
    }

    It 'preserves default flat prices with all HNS products and unrelated index records present' {
        $script:catalog += $script:hnsCatalog
        $index = $script:records[0].PSObject.Copy()
        $index.RecordType = 'CurrentIndexCapacity'; $index.CapacityStatus = 'LatestSample'
        $rows = @(Get-AzStorageRedundancyCost -Records ($script:records + @($index)) -ModelMonth '2026-09')
        @($rows | Where-Object Component -eq 'HnsIndexCapacity').Count | Should Be 0
        @($rows | Where-Object { $_.PricingMode -ne 'BlobFlat' }).Count | Should Be 0
        @($rows | Where-Object { $_.RecordType -eq 'Scenario' -and $_.PricedSubtotal -ne [decimal]0.042 }).Count | Should Be 0
        $script:records[0].IsHnsEnabled = $true
        $rows = @(Get-AzStorageRedundancyCost -Records $script:records -ModelMonth '2026-09' -WarningAction SilentlyContinue)
        @($rows | Where-Object { $null -ne $_.EstimatedCost -or $null -ne $_.PricedSubtotal }).Count | Should Be 0
    }
}
