function Get-AzContext { param([switch]$ListAvailable) }
function Invoke-AzRestMethod { param($Path, $Method, $DefaultProfile) }

Describe 'Monthly workload baseline through Get-AzStorageTransactionMetric' {
    BeforeEach {
        . "$PSScriptRoot\..\Get-AzStorageTransactionMetric.ps1"
        $script:sub = '11111111-1111-1111-1111-111111111111'
        $script:id = "/subscriptions/$script:sub/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/testaccount"
        $script:end = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero)
        $script:start = $script:end.AddMonths(-1)
        $script:csv = "$TestDrive\cost.csv"
        $script:costRows = @(
            [pscustomobject]@{
                ResourceId = $script:id; Date = $script:start.ToString('yyyy-MM-dd')
                MeterId = 'capacity-meter'; MeterName = 'Hot LRS Data Stored'
                MeterSubCategory = 'Blob Storage'; ProductName = 'Blob Storage'
                Quantity = '2'; UnitOfMeasure = '1 GB/Month'; ChargeType = 'Usage'
                CostInBillingCurrency = '0.04'; BillingCurrency = 'USD'
            }
        )
        $script:blobBytes = [long]2147483648
        $script:hns = $false
        $script:indexBytes = [long]1073741824
        $script:missingCapacity = $false
        $script:capacityFailure = $false
        $script:missingRequests = $false
        $script:blobType = 'BlockBlob'
        $script:capacityTier = 'Hot'
        $script:ops = @(@{ Api = 'GetBlob'; Tier = 'Hot'; Response = 'Success'; Count = 3 })
        Mock Get-AzContext {
            [pscustomobject]@{ Subscription = @{ Id = $script:sub; Name = 'Example' } }
        }
        Mock Invoke-AzRestMethod {
            if ($Path -notmatch 'Microsoft.Insights') {
                return [pscustomobject]@{ StatusCode = 200; Content = (@{
                    kind = 'StorageV2'; sku = @{ name = 'Standard_LRS' }; location = 'eastus'
                    properties = @{ isHnsEnabled = $script:hns; accessTier = 'Hot' }
                } | ConvertTo-Json -Depth 5) }
            }
            if ($Path -match 'metricnames=Transactions') {
                $series = @()
                $total = [decimal]0
                foreach ($op in $script:ops) {
                    $total += $op.Count
                    if ($Path -match '%24filter=') {
                        $series += @{
                            metadatavalues = @(
                                @{ name = @{ value = 'ApiName' }; value = $op.Api }
                                @{ name = @{ value = 'Tier' }; value = $op.Tier }
                                @{ name = @{ value = 'ResponseType' }; value = $op.Response }
                                @{ name = @{ value = 'GeoType' }; value = 'Primary' }
                                @{ name = @{ value = 'Authentication' }; value = 'OAuth' }
                                @{ name = @{ value = 'TransactionType' }; value = 'User' }
                            )
                            data = @(@{ total = $(if ($script:missingRequests) { $null } else { $op.Count }) })
                        }
                    }
                }
                if ($Path -notmatch '%24filter=') {
                    $series = @(@{ data = @(@{ total = $(if ($script:missingRequests) { $null } else { $total }) }) })
                }
                return [pscustomobject]@{ StatusCode = 200; Content = (@{
                    value = @(@{ name = @{ value = 'Transactions' }; unit = 'Count'; errorCode = 'Success'; timeseries = $series })
                } | ConvertTo-Json -Depth 12) }
            }
            if ($script:capacityFailure) { throw 'Capacity unavailable' }
            $decoded = [uri]::UnescapeDataString($Path)
            [void]($decoded -match 'timespan=([^&]+)')
            $range = $Matches[1].Split('/')
            $first = [datetimeoffset]$range[0]
            $last = [datetimeoffset]$range[1]
            $metric = if ($Path -match 'metricnames=IndexCapacity') { 'IndexCapacity' } else { 'BlobCapacity' }
            $bytes = if ($metric -eq 'IndexCapacity') { $script:indexBytes } else { $script:blobBytes }
            $series = @{
                data = @(
                    for ($time = $first; $time -lt $last; $time = $time.AddHours(1)) {
                        @{ timeStamp = $time.ToString('o'); average = $(if ($script:missingCapacity -and $time -eq $script:start) { $null } else { $bytes }) }
                    }
                )
            }
            if ($Path -match '%24filter=') {
                $series.metadatavalues = @(
                    @{ name = @{ value = 'Tier' }; value = $script:capacityTier }
                    @{ name = @{ value = 'BlobType' }; value = $script:blobType }
                )
            }
            [pscustomobject]@{ StatusCode = 200; Content = (@{
                interval = 'PT1H'
                value = @(@{ name = @{ value = $metric }; unit = 'Bytes'; errorCode = 'Success'; timeseries = @($series) })
            } | ConvertTo-Json -Depth 12) }
        }
    }

    It 'normalizes sampled capacity to binary GiBMonth and compares the same complete month' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $workload = $rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' }
        $workload.Quantity | Should Be 2
        $workload.QuantityUnit | Should Be 'GiBMonth'
        $workload.Tier | Should Be 'Hot'
        $workload.BlobType | Should Be 'BlockBlob'
        $workload.QuantitySource | Should Be 'AzureMonitor'
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ObservedCapacityGiBMonth | Should Be 2
        $comparison.BilledCapacityGiBMonth | Should Be 2
        $comparison.CapacityDifferenceGiBMonth | Should Be 0
        $comparison.ComparisonStatus | Should Be 'QuantitiesMatch'
        $comparison.BillingCoverageStatus | Should Be 'CsvCoverageUnverified'
        @($rows | Where-Object RecordType -eq 'Detail').Count | Should Be 1
        @($rows | Where-Object RecordType -eq 'CapacityAccountTotal').Count | Should Be 1
    }

    It 'compares HNS index independently instead of adding its space to Blob data' {
        $script:hns = $true
        $index = $script:costRows[0].PSObject.Copy()
        $index.MeterId = 'index-meter'
        $index.MeterName = 'Hot LRS Index'
        $index.MeterSubCategory = 'Azure Data Lake Storage Gen2'
        $index.Quantity = '1'
        @($script:costRows[0], $index) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $indexComparison = $rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $_.QuantityKind -eq 'HnsIndexCapacity' }
        $indexComparison.ObservedCapacityGiBMonth | Should Be 1
        $indexComparison.BilledCapacityGiBMonth | Should Be 1
        $indexComparison.ComparisonStatus | Should Be 'QuantitiesMatch'
        ($rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $_.QuantityKind -eq 'UsedCapacity' }).ObservedCapacityGiBMonth | Should Be 2
        @($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'HnsIndexCapacity' }).Count | Should Be 1
    }

    It 'keeps request dimensions and billability distinct from normalized billed operations' {
        $script:ops = @(
            @{ Api = 'GetBlob'; Tier = 'Hot'; Response = 'Success'; Count = 3 },
            @{ Api = 'GetBlob'; Tier = 'Cool'; Response = 'AuthorizationError'; Count = 2 },
            @{ Api = 'DeleteBlob'; Tier = 'Hot'; Response = 'Success'; Count = 4 },
            @{ Api = 'NewApi'; Tier = 'Hot'; Response = 'Success'; Count = 5 }
        )
        $read = $script:costRows[0].PSObject.Copy()
        $read.MeterId = 'read-meter'
        $read.MeterName = 'Hot Read Operations'
        $read.UnitOfMeasure = '10K'
        $read.Quantity = '0.0003'
        @($script:costRows[0], $read) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $requests = @($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'ObservedRequests' })
        $requests.Count | Should Be 4
        $cool = $requests | Where-Object Tier -eq 'Cool'
        $cool.ResponseType | Should Be 'AuthorizationError'
        $cool.QuantityUnit | Should Be 'Requests'
        $cool.QuantityStatus | Should Be 'ObservedRequestsNotBillable'
        ($requests | Where-Object ApiName -eq 'DeleteBlob').QuantityStatus | Should Be 'DocumentedFreeRequests'
        ($requests | Where-Object ApiName -eq 'NewApi').QuantityStatus | Should Be 'UnmappedRequests'
        $billing = $rows | Where-Object { $_.RecordType -eq 'BilledWorkload' -and $_.MeterId -eq 'read-meter' }
        $billing.Quantity | Should Be 3
        $billing.QuantityUnit | Should Be 'Operations'
        $billing.QuantityStatus | Should Be 'BillingDerived'
        $billing.QuantityBasis | Should Be 'BillingReportedUsage'
    }

    It 'reports capacity differences without treating sampled usage as exact billing' {
        $script:costRows[0].Quantity = '1'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.CapacityDifferenceGiBMonth | Should Be 1
        $comparison.CapacityDifferencePercent | Should Be 100
        $comparison.ComparisonStatus | Should Be 'QuantitiesDiffer'
        $comparison.CompletenessStatus | Should Be 'NotBillingValidation'
    }

    It 'does not use account default tier to classify unlabeled billing capacity' {
        $script:costRows[0].MeterName = 'LRS Data Stored'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $null -eq $_.Tier }
        $comparison.ComparisonStatus | Should Be 'TierUnresolved'
        ($null -eq $comparison.ObservedCapacityGiBMonth) | Should Be $true
        $comparison.BilledCapacityGiBMonth | Should Be 2
        ($rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $_.Tier -eq 'Hot' }).ComparisonStatus | Should Be 'NoMatchingBillingMeter'
    }

    It 'blocks comparisons with multiple redundancy or currency contexts' {
        $other = $script:costRows[0].PSObject.Copy()
        $other.MeterId = 'other-meter'
        $other.MeterName = 'Hot GRS Data Stored'
        @($script:costRows[0], $other) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ComparisonStatus | Should Be 'AmbiguousBillingContext'
        ($null -eq $comparison.BilledCapacityGiBMonth) | Should Be $true
        ($null -eq $comparison.CapacityDifferenceGiBMonth) | Should Be $true
        $other.MeterName = 'Hot LRS Data Stored'
        $other.BillingCurrency = 'EUR'
        @($script:costRows[0], $other) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'CapacityComparison').ComparisonStatus | Should Be 'AmbiguousBillingContext'
    }

    It 'preserves missing samples rather than pricing the available-hour average' {
        $script:missingCapacity = $true
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -WarningAction SilentlyContinue -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        ($null -eq $comparison.ObservedCapacityGiBMonth) | Should Be $true
        $comparison.BilledCapacityGiBMonth | Should Be 2
        $comparison.ComparisonStatus | Should Be 'MetricsIncomplete'
        ($null -eq ($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' }).Quantity) | Should Be $true
    }

    It 'shows capacity query failures without claiming billing quantity agreement' {
        $script:capacityFailure = $true
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction SilentlyContinue)
        ($rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $_.Tier -eq 'Hot' }).ComparisonStatus | Should Be 'MetricsFailed'
        @($rows | Where-Object RecordType -eq 'CapacityError').Count | Should Be 1
        ($rows | Where-Object RecordType -eq 'AccountTotal').CompletenessStatus | Should Be 'Reconciled'
    }

    It 'distinguishes a failed billing import from an absent billing meter' {
        $script:costRows[0].Quantity = 'invalid'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction SilentlyContinue)
        ($rows | Where-Object RecordType -eq 'CapacityComparison').ComparisonStatus | Should Be 'BillingUnavailable'
        ($rows | Where-Object RecordType -eq 'CapacityComparison').ObservedCapacityGiBMonth | Should Be 2
        @($rows | Where-Object RecordType -eq 'CostError').Count | Should Be 1
    }

    It 'does not compare page-blob capacity with a general block-blob meter' {
        $script:blobType = 'PageBlob'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ComparisonStatus | Should Be 'UnsupportedBlobType'
        ($null -eq $comparison.ObservedCapacityGiBMonth) | Should Be $true
        ($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' }).BlobType | Should Be 'PageBlob'
    }

    It 'retains zero quantities without dividing by zero or synthesizing absent meters' {
        $script:blobBytes = 0
        $script:costRows[0].Quantity = '0'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ObservedCapacityGiBMonth | Should Be 0
        $comparison.BilledCapacityGiBMonth | Should Be 0
        $comparison.ComparisonStatus | Should Be 'QuantitiesMatch'
        ($null -eq $comparison.CapacityDifferencePercent) | Should Be $true
        $script:costRows[0].MeterName = 'Hot Read Operations'
        $script:costRows[0].UnitOfMeasure = '10K'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ComparisonStatus | Should Be 'NoMatchingBillingMeter'
        ($null -eq $comparison.BilledCapacityGiBMonth) | Should Be $true
    }

    It 'retains unknown and unverified billing meters without assigning usable quantities' {
        $script:costRows[0].UnitOfMeasure = 'Unknown'
        $unknown = $script:costRows[0].PSObject.Copy()
        $unknown.MeterId = 'unknown-meter'
        $unknown.MeterName = 'Unknown feature'
        @($script:costRows[0], $unknown) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $unverified = $rows | Where-Object { $_.RecordType -eq 'BilledWorkload' -and $_.MeterId -eq 'capacity-meter' }
        $unverified.QuantityStatus | Should Be 'UnverifiedUnit'
        ($null -eq $unverified.Quantity) | Should Be $true
        $unclassified = $rows | Where-Object { $_.RecordType -eq 'BilledWorkload' -and $_.MeterId -eq 'unknown-meter' }
        $unclassified.QuantityKind | Should Be 'UnclassifiedMeter'
        $unclassified.QuantityStatus | Should Be 'Unclassified'
        $unclassified.BilledQuantity | Should Be 2
        ($rows | Where-Object RecordType -eq 'CapacityComparison').ComparisonStatus | Should Be 'UnverifiedUnit'
    }

    It 'excludes refunds and flags negative usage rather than turning adjustments into workload' {
        $refund = $script:costRows[0].PSObject.Copy()
        $refund.Quantity = '-1'
        $refund.ChargeType = 'Refund'
        @($script:costRows[0], $refund) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.BilledCapacityGiBMonth | Should Be 2
        $comparison.ComparisonStatus | Should Be 'QuantitiesMatch'
        $nonUsage = $rows | Where-Object { $_.RecordType -eq 'BilledWorkload' -and $_.ChargeType -eq 'Refund' }
        $nonUsage.QuantityStatus | Should Be 'NonUsageCharge'
        ($null -eq $nonUsage.Quantity) | Should Be $true
        $refund.ChargeType = 'Usage'
        @($script:costRows[0], $refund) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -IncludeCostDetail -ErrorAction Stop)
        $comparison = $rows | Where-Object RecordType -eq 'CapacityComparison'
        $comparison.ComparisonStatus | Should Be 'BillingAdjustmentsPresent'
        ($null -eq $comparison.BilledCapacityGiBMonth) | Should Be $true
        $billing = $rows | Where-Object RecordType -eq 'BilledWorkload'
        $billing.QuantityStatus | Should Be 'BillingAdjustmentsPresent'
        ($null -eq $billing.Quantity) | Should Be $true
        $billing.NormalizedBilledQuantity | Should Be 1
    }

    It 'does not mistake daily evidence and overlapping totals for additional measured quantities' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -IncludeCostDetail -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostDetail').Count | Should Be 1
        @($rows | Where-Object RecordType -eq 'BilledWorkload').Count | Should Be 1
        @($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' }).Count | Should Be 1
        @($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.SourceRecordType -in @('AccountTotal', 'Summary', 'CapacityAccountTotal', 'CostDetail') }).Count | Should Be 0
    }

    It 'keeps baseline requests null when the month has incomplete metric counts' {
        $script:missingRequests = $true
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -WarningAction SilentlyContinue -ErrorAction Stop)
        $requests = $rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'ObservedRequests' }
        ($null -eq $requests.Quantity) | Should Be $true
        $requests.QuantityStatus | Should Be 'MissingData'
    }

    It 'keeps accounts separate and retains flat baseline fields in CSV and JSON under strict mode' {
        $other = $script:costRows[0].PSObject.Copy()
        $other.ResourceId = $script:id.Replace('testaccount', 'otheraccount')
        $other.Quantity = '1'
        @($script:costRows[0], $other) | Export-Csv $script:csv -NoTypeInformation
        Set-StrictMode -Version Latest
        try {
            $rows = @(@($script:id, $other.ResourceId) | Get-AzStorageTransactionMetric -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
            $comparisons = @($rows | Where-Object RecordType -eq 'CapacityComparison')
            $comparisons.Count | Should Be 2
            ($comparisons | Where-Object ResourceId -eq $script:id).ComparisonStatus | Should Be 'QuantitiesMatch'
            ($comparisons | Where-Object ResourceId -eq $other.ResourceId).ComparisonStatus | Should Be 'QuantitiesDiffer'
            $rows | Export-Csv "$TestDrive\baseline.csv" -NoTypeInformation
            $csv = @(Import-Csv "$TestDrive\baseline.csv" | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' })
            $csv[0].Quantity | Should Be '2'
            $csv[0].QuantityUnit | Should Be 'GiBMonth'
            $json = ConvertTo-Json -InputObject $rows -Depth 4 | ConvertFrom-Json
            ($null -eq ($json | Where-Object RecordType -eq 'AccountTotal')[0].Quantity) | Should Be $true
        } finally { Set-StrictMode -Off }
    }

    It 'requires an explicit billing source and a full monthly period before requests' {
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeWorkloadBaseline } | Should Throw 'requires IncludeCostComparison or CostDetailsCsv'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddDays(1) -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline } | Should Throw 'completed UTC'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -SummaryPeriod Chunk -CostDetailsCsv $script:csv -IncludeWorkloadBaseline } | Should Throw 'completed UTC'
        Assert-MockCalled Invoke-AzRestMethod -Scope It -Times 0
    }

    It 'does not reinterpret Untiered capacity as the default Hot tier' {
        $script:capacityTier = 'Untiered'
        $script:costRows[0].MeterName = 'LRS Data Stored'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CapacityComparison' -and $_.Tier -eq 'Untiered' }
        $comparison.ComparisonStatus | Should Be 'TierUnresolved'
        ($null -eq $comparison.ObservedCapacityGiBMonth) | Should Be $true
        ($rows | Where-Object { $_.RecordType -eq 'Workload' -and $_.QuantityKind -eq 'UsedCapacity' }).Quantity | Should Be 2
    }

    It 'keeps each month distinct and never combines capacities across billing months' {
        $earlier = $script:costRows[0].PSObject.Copy()
        $earlier.Date = $script:start.AddMonths(-1).ToString('yyyy-MM-dd')
        $earlier.Quantity = '1'
        $script:start = $script:start.AddMonths(-1)
        @($earlier, $script:costRows[0]) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeWorkloadBaseline -ErrorAction Stop)
        $comparisons = @($rows | Where-Object RecordType -eq 'CapacityComparison')
        $comparisons.Count | Should Be 2
        $comparisons[0].ObservedCapacityGiBMonth | Should Be 2
        $comparisons[0].BilledCapacityGiBMonth | Should Be 1
        $comparisons[0].ComparisonStatus | Should Be 'QuantitiesDiffer'
        $comparisons[1].BilledCapacityGiBMonth | Should Be 2
        $comparisons[1].ComparisonStatus | Should Be 'QuantitiesMatch'
        $comparisons[0].Month | Should Not Be $comparisons[1].Month
    }

    It 'does not emit baseline rows when the opt-in switch is absent' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        @($rows | Where-Object RecordType -in @('Workload', 'BilledWorkload', 'CapacityComparison')).Count | Should Be 0
        Assert-MockCalled Invoke-AzRestMethod -Scope It -Times 0 -ParameterFilter { $Path -match 'metricnames=BlobCapacity' }
    }
}
