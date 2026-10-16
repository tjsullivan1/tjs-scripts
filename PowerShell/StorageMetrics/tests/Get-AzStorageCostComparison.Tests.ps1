[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Offline Az boundary stubs retain the parameters consumed by Pester mocks.')]
param()

BeforeAll {
    Import-Module "$PSScriptRoot\..\StorageMetrics.psd1" -Force -ErrorAction Stop
    InModuleScope StorageMetrics {
        function script:Get-AzContext { param([switch]$ListAvailable) }
        function script:Invoke-AzRestMethod { param($Path, $Uri, $Method, $Payload, $DefaultProfile) }
    }
}

Describe 'Storage cost comparison through Get-AzStorageTransactionMetric' {
    BeforeEach {
        Mock Get-UtcNow -ModuleName StorageMetrics { [datetimeoffset]'2026-10-16T12:00:00Z' }
        $script:sub = '11111111-1111-1111-1111-111111111111'
        $script:id = "/subscriptions/$script:sub/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/testaccount"
        $script:end = [datetimeoffset]::new(2026, 10, 1, 0, 0, 0, [timespan]::Zero)
        $script:start = $script:end.AddMonths(-1)
        $script:csv = "$TestDrive\cost.csv"
        $script:costRows = @(
            [pscustomobject]@{
                ResourceId = $script:id; Date = $script:start.ToString('yyyy-MM-dd')
                MeterId = 'read-meter'; MeterName = 'Hot Read Operations'
                MeterSubCategory = 'Blob Storage'; ProductName = 'Blob Storage - Hot LRS'
                Quantity = '0.0003'; UnitOfMeasure = '10K'; ChargeType = 'Usage'
                CostInBillingCurrency = '0.00012'; BillingCurrency = 'USD'
            }
        )
        $script:metricCalls = 0
        $script:reportCalls = 0
        $script:downloadCalls = 0
        $script:reportFailure = $false
        $script:missingMetrics = $false
        $script:badPollHost = $false
        $script:downloadFailure = $false
        $script:pollCalls = 0
        $script:pendingPolls = 0
        $script:retryAfter = '1'
        $script:badManifest = $false
        Mock Get-AzContext -ModuleName StorageMetrics {
            [pscustomobject]@{ Subscription = @{ Id = $script:sub }; Environment = @{
                ResourceManagerUrl = 'https://management.azure.com/'
                StorageEndpointSuffix = 'core.windows.net'
            } }
        }
        Mock Invoke-AzRestMethod -ModuleName StorageMetrics {
            param($Path, $Uri)
            if ($Path -match 'generateCostDetailsReport') {
                $script:reportCalls++
                if ($script:reportFailure) { return [pscustomobject]@{StatusCode=403;Content='Denied'} }
                $hostName = if ($script:badPollHost) { 'untrusted.example' } else { 'management.azure.com' }
                return [pscustomobject]@{StatusCode=202; Content=''; Headers=@(
                    [pscustomobject]@{Key='Location'; Value=@("https://$hostName/subscriptions/$script:sub/providers/Microsoft.CostManagement/costDetailsOperationResults/report?api-version=2022-05-01")}
                    [pscustomobject]@{Key='Retry-After'; Value=@($script:retryAfter)}
                )}
            }
            if ($Uri -match 'costDetailsOperationResults') {
                $script:pollCalls++
                if ($script:pollCalls -le $script:pendingPolls) {
                    return [pscustomobject]@{StatusCode=202;Content='';Headers=@(
                        [pscustomobject]@{Key='Retry-After';Value=@($script:retryAfter)}
                    )}
                }
                if ($script:badManifest) {
                    return [pscustomobject]@{StatusCode=200;Content='{"manifest":{"blobCount":3,"compressData":false,"dataFormat":"Csv","blobs":[]}}'}
                }
                return [pscustomobject]@{StatusCode=200;Content='{"manifest":{"blobCount":2,"compressData":false,"dataFormat":"Csv","blobs":[{"blobLink":"https://reports.blob.core.windows.net/part1.csv"},{"blobLink":"https://reports.blob.core.windows.net/part2.csv"}]}}'}
            }
            if ($Path -notmatch 'Microsoft.Insights') {
                return [pscustomobject]@{StatusCode=200; Content='{"kind":"StorageV2","sku":{"name":"Standard_LRS"},"properties":{},"location":"eastus"}'}
            }
            $script:metricCalls++
            $count = if ($script:metricCalls -le 2) { 3 } else { 0 }
            if ($script:missingMetrics) { $count = $null }
            $series = @{ data = @(@{ total = $count }) }
            if ($Path -match '%24filter=') {
                $series.metadatavalues = @(
                    foreach ($pair in @(
                        @('ApiName','GetBlob'), @('ResponseType','Success'), @('Tier','Hot'),
                        @('GeoType','Primary'), @('Authentication','OAuth'), @('TransactionType','user')
                    )) { @{name=@{value=$pair[0]};value=$pair[1]} }
                )
            }
            [pscustomobject]@{StatusCode=200; Content=(@{
                value=@(@{name=@{value='Transactions'};unit='Count';errorCode='Success';timeseries=@($series)})
            } | ConvertTo-Json -Depth 10)}
        }
        Mock Start-Sleep -ModuleName StorageMetrics {}
        Mock Invoke-WebRequest -ModuleName StorageMetrics {
            $script:downloadCalls++
            if ($script:downloadFailure) { throw 'Download failed: https://reports.blob.core.windows.net/private.csv?sig=secret' }
            $script:costRows | Export-Csv -LiteralPath $OutFile -NoTypeInformation
        }
    }

    It 'compares CSV billed quantities with monthly observed requests without altering metrics' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should -Be 3
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.RequestCount | Should -Be 3
        $comparison.BilledOperationCount | Should -Be 3
        $comparison.RequestMinusBilledCount | Should -Be 0
        $comparison.ActualCost | Should -Be 0.00012
        $comparison.Currency | Should -Be 'USD'
        $comparison.ComparisonStatus | Should -Be 'CountsMatch'
        ($rows | Where-Object RecordType -eq 'CostMeter').MeterId | Should -Be 'read-meter'
    }

    It 'retrieves a live asynchronous report and includes every CSV partition' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.BilledOperationCount | Should -Be 6
        ($comparison.RequestMinusBilledCount -eq -3) | Should -Be $true
        $comparison.ComparisonStatus | Should -Be 'CountsDiffer'
        $comparison.CostSource | Should -Be 'CostDetailsApi'
        $script:reportCalls | Should -Be 1
        $script:downloadCalls | Should -Be 2
        Should -Invoke Start-Sleep -ModuleName StorageMetrics -Scope It -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1 }
    }

    It 'does not compare Defender transactions with Blob operations' {
        $script:costRows[0].MeterName = 'Standard Transactions'
        $script:costRows[0].MeterSubCategory = 'Microsoft Defender for Storage'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $meter = $rows | Where-Object RecordType -eq 'CostMeter'
        $meter.ComparisonStatus | Should -Be 'NotOperationMeter'
        ($null -eq $meter.BilledOperationCount) | Should -Be $true
        $meter.ActualCost | Should -Be 0.00012
    }

    It 'keeps absent billing meters null instead of reporting zero charges' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Writes' }
        $comparison.ComparisonStatus | Should -Be 'NoMatchingBillingMeter'
        ($null -eq $comparison.BilledOperationCount) | Should -Be $true
        ($null -eq $comparison.ActualCost) | Should -Be $true
    }

    It 'does not assume an operation unit multiplier from cost or meter name' {
        $script:costRows[0].UnitOfMeasure = 'MysteryUnits'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.ComparisonStatus | Should -Be 'UnverifiedUnit'
        ($null -eq $comparison.BilledOperationCount) | Should -Be $true
    }

    It 'keeps currencies and tier meters separate and excludes refunds from usage comparisons' {
        $other = $script:costRows[0].PSObject.Copy()
        $other.BillingCurrency = 'EUR'
        $other.MeterId = 'cool-meter'
        $other.MeterName = 'Cool Read Operations'
        $refund = $script:costRows[0].PSObject.Copy()
        $refund.ChargeType = 'Refund'
        $refund.Quantity = '-0.0003'
        $refund.CostInBillingCurrency = '-0.00012'
        @($script:costRows[0],$other,$refund) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $comparisons = @($rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' })
        $comparisons.Count | Should -Be 2
        $comparisons[0].BilledOperationCount | Should -Be 3
        $comparisons[1].BilledOperationCount | Should -Be 3
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 3
        ($rows | Where-Object ChargeType -eq 'Refund').ComparisonStatus | Should -Be 'NonUsageCharge'
    }

    It 'filters billing rows by exact account and usage date' {
        $old = $script:costRows[0].PSObject.Copy()
        $old.Date = $script:end.ToString('yyyy-MM-dd')
        $other = $script:costRows[0].PSObject.Copy()
        $other.ResourceId = $script:id.Replace('testaccount','otheraccount')
        @($script:costRows[0],$old,$other) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 1
        ($rows | Where-Object RecordType -eq 'CostMeter').BilledOperationCount | Should -Be 3
    }

    It 'marks comparisons incomplete without losing available billed quantities' {
        $script:missingMetrics = $true
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -WarningAction SilentlyContinue -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.ComparisonStatus | Should -Be 'MetricsIncomplete'
        $comparison.BilledOperationCount | Should -Be 3
        ($null -eq $comparison.RequestMinusBilledCount) | Should -Be $true
    }

    It 'surfaces cost access failures separately without discarding valid Monitor results' {
        $script:reportFailure = $true
        $errors = @()
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction SilentlyContinue -ErrorVariable errors)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should -Be 3
        ($rows | Where-Object RecordType -eq 'CostError').Message | Should -Match '403'
        @($errors | Where-Object FullyQualifiedErrorId -like 'StorageCostComparisonFailed*').Count | Should -Be 1
        @($rows | Where-Object RecordType -eq 'CostComparison').Count | Should -Be 0
    }

    It 'rejects report polling URLs outside the authenticated ARM endpoint' {
        $script:badPollHost = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should -Throw '*invalid polling location*'
        $script:downloadCalls | Should -Be 0
    }

    It 'does not expose signed download URLs in error records' {
        $script:downloadFailure = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction SilentlyContinue)
        $errorRow = $rows | Where-Object RecordType -eq 'CostError'
        $errorRow.Message | Should -Match 'download failed'
        $errorRow.Message | Should -Not -Match 'sig=|secret'
    }

    It 'rejects partial-month or chunk-based cost comparisons before Azure requests' {
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddDays(1) -EndTime $script:end -IncludeCostComparison } | Should -Throw '*completed UTC*'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -SummaryPeriod Chunk -IncludeCostComparison } | Should -Throw '*completed UTC*'
        $script:metricCalls | Should -Be 0
    }

    It 'retains cost fields when exporting the mixed flat output' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $rows | Export-Csv "$TestDrive\comparison.csv" -NoTypeInformation
        $exported = Import-Csv "$TestDrive\comparison.csv"
        ($exported | Where-Object RecordType -eq 'CostMeter').MeterName | Should -Be 'Hot Read Operations'
        ($exported | Where-Object RecordType -eq 'CostMeter').ActualCost | Should -Be '0.00012'
    }

    It 'supports CSV comparisons under strict mode' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
            @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 1
        } finally { Set-StrictMode -Off }
    }

    It 'retains the polling location across subsequent pending responses' {
        $script:pendingPolls = 1
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop)
        $script:pollCalls | Should -Be 2
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 1
    }

    It 'bounds polling instead of waiting indefinitely' {
        $script:pendingPolls = 100
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should -Throw '*polling limit*'
        $script:downloadCalls | Should -Be 0
    }

    It 'stops polling when the injected clock reaches the report deadline' {
        $script:clock = [datetimeoffset]'2026-10-16T12:00:00Z'
        $script:pendingPolls = 1
        Mock Get-UtcNow -ModuleName StorageMetrics { $script:clock }
        Mock Start-Sleep -ModuleName StorageMetrics { $script:clock = [datetimeoffset]'2026-10-16T12:10:00Z' }
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } |
            Should -Throw '*polling limit*'
        $script:pollCalls | Should -Be 1
        $script:downloadCalls | Should -Be 0
        Should -Invoke Start-Sleep -ModuleName StorageMetrics -Scope It -Times 1 -Exactly
    }

    It 'allows a configurable Cost Details polling timeout up to sixty minutes' {
        $script:retryAfter = '601'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start `
            -EndTime $script:end -IncludeCostComparison -CostReportTimeoutMinutes 20 -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 1
        Should -Invoke Start-Sleep -ModuleName StorageMetrics -Scope It -Times 1 -Exactly -ParameterFilter { $Seconds -eq 601 }
    }

    It 'uses a ten-minute Cost Details polling timeout by default' {
        $script:retryAfter = '601'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start `
            -EndTime $script:end -IncludeCostComparison -ErrorAction SilentlyContinue)
        @($rows | Where-Object RecordType -eq 'CostError').Count | Should -Be 1
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 0
    }

    It 'rejects Cost Details polling timeouts greater than sixty minutes' {
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start `
            -EndTime $script:end -IncludeCostComparison -CostReportTimeoutMinutes 61 } |
            Should -Throw '*validate argument*'
        $script:metricCalls | Should -Be 0
        $script:reportCalls | Should -Be 0
    }

    It 'filters unrelated rows before parsing dates and handles a 50000-row billing CSV efficiently' {
        $ids = @($script:id)
        $writer = [IO.StreamWriter]::new($script:csv, $false, [Text.UTF8Encoding]::new($false))
        try {
            $writer.WriteLine('"ResourceId","Date","MeterId","MeterName","MeterSubCategory","ProductName","Quantity","UnitOfMeasure","ChargeType","CostInBillingCurrency","BillingCurrency"')
            for ($index = 1; $index -lt 50000; $index++) {
                $writer.WriteLine("/subscriptions/$script:sub/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/unrelated-$index,not-a-date,,,,,,,,,")
            }
            $writer.WriteLine("$script:id,$($script:start.ToString('yyyy-MM-dd')),read-meter,Hot Read Operations,Blob Storage,Blob Storage - Hot LRS,0.0003,10K,Usage,0.00012,USD")
        } finally {
            $writer.Dispose()
        }

        $timer = [Diagnostics.Stopwatch]::StartNew()
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $ids -StartTime $script:start `
            -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $timer.Stop()

        $meters = @($rows | Where-Object RecordType -eq 'CostMeter')
        $meters.Count | Should -Be 1
        $meters[0].ResourceId | Should -Be $script:id
        $meters[0].BilledOperationCount | Should -Be 3
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 30
    }

    It 'rejects incomplete report manifests rather than comparing a partial download' {
        $script:badManifest = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should -Throw '*every report partition*'
        $script:downloadCalls | Should -Be 0
    }

    It 'rejects duplicate CSV paths instead of double-counting billed quantities' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv @($script:csv,$script:csv) -ErrorAction Stop } | Should -Throw '*Duplicate cost CSV*'
    }

    It 'reports malformed cost numbers as a cost failure' {
        $script:costRows[0].Quantity = 'invalid'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction SilentlyContinue)
        ($rows | Where-Object RecordType -eq 'CostError').Message | Should -Match 'Invalid cost details number'
    }

    It 'excludes unassigned billing charges without invalidating account comparisons' {
        $unassigned = $script:costRows[0].PSObject.Copy()
        $unassigned.ResourceId = ''
        @($script:costRows[0],$unassigned) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -WarningAction SilentlyContinue -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should -Be 1
        ($rows | Where-Object RecordType -eq 'CostMeter').BilledOperationCount | Should -Be 3
    }

    It 'preserves daily billing evidence and does not merge different rate or benefit contexts' {
        $first = $script:costRows[0].PSObject.Copy()
        $first | Add-Member NoteProperty MeterRegion 'US East'
        $first | Add-Member NoteProperty PricingModel 'OnDemand'
        $first | Add-Member NoteProperty EffectivePrice '0.4'
        $first | Add-Member NoteProperty UnitPrice '0.5'
        $first | Add-Member NoteProperty PayGPrice '0.6'
        $first | Add-Member NoteProperty PricingCurrency 'USD'
        $first | Add-Member NoteProperty ReservationId ''
        $first | Add-Member NoteProperty BenefitId ''
        $second = $first.PSObject.Copy()
        $second.Date = $script:start.AddDays(1).ToString('yyyy-MM-dd')
        $second.PricingModel = 'Reservation'
        $second.ReservationId = 'reservation'
        $second.BenefitId = 'benefit'
        $second.EffectivePrice = '0'
        $second.CostInBillingCurrency = '0'
        @($first, $second) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeCostDetail -ErrorAction Stop)
        $meters = @($rows | Where-Object RecordType -eq 'CostMeter')
        $details = @($rows | Where-Object RecordType -eq 'CostDetail')
        $meters.Count | Should -Be 2
        $details.Count | Should -Be 2
        $details[1].BillingUsageDate | Should -Be $script:start.AddDays(1).ToString('yyyy-MM-dd')
        $details[1].ReservationId | Should -Be 'reservation'
        $details[1].BilledOperationCount | Should -Be 3
        $details[1].ActualCost | Should -Be 0
        $details[0].MeterRegion | Should -Be 'US East'
        $details[0].UnitPrice | Should -Be 0.5
        $details[0].PayGPrice | Should -Be 0.6
        $details[0].BillingCoverageStatus | Should -Be 'CsvCoverageUnverified'
        $rows | Export-Csv "$TestDrive\evidence.csv" -NoTypeInformation
        (Import-Csv "$TestDrive\evidence.csv" | Where-Object { $_.RecordType -eq 'CostDetail' -and $_.PricingModel -eq 'Reservation' }).BenefitId | Should -Be 'benefit'
    }

    It 'classifies capacity retrieval early deletion and feature quantities without inventing byte units' {
        $cases = @(
            @('Hot RA-GRS Data Stored', 'Blob Storage', '1 GB/Month', 'Capacity', 'GiBMonth', 2),
            @('Hot LRS Index', 'Azure Data Lake Storage Gen2', '1 GB/Month', 'HnsIndexCapacity', 'GiBMonth', 2),
            @('Cool Data Retrieval', 'Blob Storage', '1 GB', 'Retrieval', 'BillingGB', 2),
            @('Archive LRS Early Delete', 'Blob Storage', '1 GB', 'EarlyDeletion', 'BillingGB', 2),
            @('Hot Data Scanned for Query Acceleration', 'Azure Data Lake Storage Gen2', '1 GB', 'QueryAccelerationScanned', 'BillingGB', 2),
            @('Hot Data Returned for Query Acceleration', 'Azure Data Lake Storage Gen2', '1 GB', 'QueryAccelerationReturned', 'BillingGB', 2),
            @('Cold ZRS Blob Inventory', 'General Block Blob v2', '1M', 'InventoryObjects', 'Objects', 2000000),
            @('Hot LRS Named Encryption Scopes', 'Blob Features', '1/Month', 'EncryptionScopes', 'ScopeMonths', 2),
            @('SSH File Transfer Protocol GRS Hour Enabled', 'Blob Features', '1', 'SftpEnabledHours', 'Hours', 2)
        )
        $billingRows = @(
            for ($index = 0; $index -lt $cases.Count; $index++) {
                $row = $script:costRows[0].PSObject.Copy()
                $row.MeterId = "meter-$index"
                $row.MeterName = $cases[$index][0]
                $row.MeterSubCategory = $cases[$index][1]
                $row.UnitOfMeasure = $cases[$index][2]
                $row.Quantity = '2'
                $row
            }
        )
        $billingRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        for ($index = 0; $index -lt $cases.Count; $index++) {
            $meter = $rows | Where-Object { $_.RecordType -eq 'CostMeter' -and $_.MeterId -eq "meter-$index" }
            $meter.BillingQuantityKind | Should -Be $cases[$index][3]
            $meter.NormalizedBilledUnit | Should -Be $cases[$index][4]
            $meter.NormalizedBilledQuantity | Should -Be $cases[$index][5]
            ($null -eq $meter.BilledOperationCount) | Should -Be $true
            $meter.QuantityBasis | Should -Be 'BillingReportedUsage'
        }
        $capacity = $rows | Where-Object MeterId -eq 'meter-0'
        $capacity.BillingTier | Should -Be 'Hot'
        $capacity.BillingRedundancy | Should -Be 'RA-GRS'
    }

    It 'normalizes the documented per-100 iterative write unit' {
        $script:costRows[0].MeterName = 'Hot Iterative Write Operations'
        $script:costRows[0].MeterSubCategory = 'Azure Data Lake Storage Gen2'
        $script:costRows[0].Quantity = '2'
        $script:costRows[0].UnitOfMeasure = '100'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $meter = $rows | Where-Object RecordType -eq 'CostMeter'
        $meter.BilledOperationCount | Should -Be 200
        $meter.NormalizedBilledQuantity | Should -Be 200
        $meter.BillingMappingStatus | Should -Be 'VerifiedOperationUnit'
    }

    It 'keeps unknown units and unknown meters raw instead of extrapolating quantities' {
        $script:costRows[0].MeterName = 'LRS Data Stored'
        $script:costRows[0].UnitOfMeasure = 'MysteryUnits'
        $unknown = $script:costRows[0].PSObject.Copy()
        $unknown.MeterId = 'unknown-meter'
        $unknown.MeterName = 'New Feature'
        @($script:costRows[0], $unknown) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        ($rows | Where-Object MeterId -eq 'read-meter').BillingMappingStatus | Should -Be 'UnverifiedUnit'
        $meter = $rows | Where-Object MeterId -eq 'unknown-meter'
        $meter.BillingMappingStatus | Should -Be 'Unclassified'
        ($null -eq $meter.NormalizedBilledQuantity) | Should -Be $true
        $meter.BilledQuantity | Should -Be 0.0003
    }

    It 'supports legacy UsageDateTime and keeps billing coverage independent of Monitor reconciliation' {
        $row = $script:costRows[0].PSObject.Copy()
        $row.PSObject.Properties.Remove('Date')
        $row | Add-Member NoteProperty UsageDateTime ($script:start.ToString('yyyy-MM-ddTHH:mm:ssZ'))
        $row | Export-Csv $script:csv -NoTypeInformation
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -IncludeCostDetail -ErrorAction Stop)
            ($rows | Where-Object RecordType -eq 'CostDetail').BillingUsageDate | Should -Be $script:start.ToString('yyyy-MM-dd')
            ($rows | Where-Object RecordType -eq 'CostMeter').CompletenessStatus | Should -Be 'CsvCoverageUnverified'
            ($rows | Where-Object RecordType -eq 'AccountTotal').CompletenessStatus | Should -Be 'Reconciled'
        } finally { Set-StrictMode -Off }
    }

    It 'does not expose detail rows by default and rejects detail without a billing source' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostDetail').Count | Should -Be 0
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostDetail } | Should -Throw '*requires IncludeCostComparison or CostDetailsCsv*'
    }

    It 'classifies network meters only in the bandwidth catalog and keeps their raw GB convention' {
        $row = $script:costRows[0].PSObject.Copy()
        $row.MeterName = 'Intra Continent Data Transfer Out'
        $row.MeterSubCategory = 'Bandwidth Inter-Region'
        $row.UnitOfMeasure = '1 GB'
        $row.Quantity = '2'
        $row | Add-Member NoteProperty MeterCategory 'Bandwidth'
        $row | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $meter = $rows | Where-Object RecordType -eq 'CostMeter'
        $meter.BillingQuantityKind | Should -Be 'NetworkTransfer'
        $meter.NormalizedBilledUnit | Should -Be 'BillingGB'
        $meter.NormalizedBilledQuantity | Should -Be 2
        ($null -eq $meter.BilledOperationCount) | Should -Be $true
    }

    It 'recognizes geo-replication transfer independently of client bandwidth' {
        $script:costRows[0].MeterName = 'Geo-Replication v2 Data Transfer'
        $script:costRows[0].MeterSubCategory = 'Geo-Replication v2'
        $script:costRows[0].ProductName = 'Storage - Bandwidth'
        $script:costRows[0].UnitOfMeasure = '1 GB'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $meter = $rows | Where-Object RecordType -eq 'CostMeter'
        $meter.BillingQuantityKind | Should -Be 'GeoReplicationTransfer'
        $meter.NormalizedBilledUnit | Should -Be 'BillingGB'
        $meter.NormalizedBilledQuantity | Should -Be 0.0003
    }
}
