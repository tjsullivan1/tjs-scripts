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
}
