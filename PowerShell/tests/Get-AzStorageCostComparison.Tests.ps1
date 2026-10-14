function Get-AzContext { param([switch]$ListAvailable) }
function Invoke-AzRestMethod { param($Path, $Uri, $Method, $Payload, $DefaultProfile) }

Describe 'Storage cost comparison through Get-AzStorageTransactionMetric' {
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
        $script:badManifest = $false
        Mock Get-AzContext {
            [pscustomobject]@{ Subscription = @{ Id = $script:sub }; Environment = @{
                ResourceManagerUrl = 'https://management.azure.com/'
                StorageEndpointSuffix = 'core.windows.net'
            } }
        }
        Mock Invoke-AzRestMethod {
            if ($Path -match 'generateCostDetailsReport') {
                $script:reportCalls++
                if ($script:reportFailure) { return [pscustomobject]@{StatusCode=403;Content='Denied'} }
                $hostName = if ($script:badPollHost) { 'untrusted.example' } else { 'management.azure.com' }
                return [pscustomobject]@{StatusCode=202; Content=''; Headers=@(
                    [pscustomobject]@{Key='Location'; Value=@("https://$hostName/subscriptions/$script:sub/providers/Microsoft.CostManagement/costDetailsOperationResults/report?api-version=2022-05-01")}
                    [pscustomobject]@{Key='Retry-After'; Value=@('1')}
                )}
            }
            if ($Uri -match 'costDetailsOperationResults') {
                $script:pollCalls++
                if ($script:pollCalls -le $script:pendingPolls) {
                    return [pscustomobject]@{StatusCode=202;Content='';Headers=@(
                        [pscustomobject]@{Key='Retry-After';Value=@('1')}
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
        Mock Start-Sleep {}
        Mock Invoke-WebRequest {
            $script:downloadCalls++
            if ($script:downloadFailure) { throw 'Download failed: https://reports.blob.core.windows.net/private.csv?sig=secret' }
            $script:costRows | Export-Csv -LiteralPath $OutFile -NoTypeInformation
        }
    }

    It 'compares CSV billed quantities with monthly observed requests without altering metrics' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 3
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.RequestCount | Should Be 3
        $comparison.BilledOperationCount | Should Be 3
        $comparison.RequestMinusBilledCount | Should Be 0
        $comparison.ActualCost | Should Be 0.00012
        $comparison.Currency | Should Be 'USD'
        $comparison.ComparisonStatus | Should Be 'CountsMatch'
        ($rows | Where-Object RecordType -eq 'CostMeter').MeterId | Should Be 'read-meter'
    }

    It 'retrieves a live asynchronous report and includes every CSV partition' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.BilledOperationCount | Should Be 6
        ($comparison.RequestMinusBilledCount -eq -3) | Should Be $true
        $comparison.ComparisonStatus | Should Be 'CountsDiffer'
        $comparison.CostSource | Should Be 'CostDetailsApi'
        $script:reportCalls | Should Be 1
        $script:downloadCalls | Should Be 2
        Assert-MockCalled Start-Sleep -Scope It -Times 1 -Exactly -ParameterFilter { $Seconds -eq 1 }
    }

    It 'does not compare Defender transactions with Blob operations' {
        $script:costRows[0].MeterName = 'Standard Transactions'
        $script:costRows[0].MeterSubCategory = 'Microsoft Defender for Storage'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $meter = $rows | Where-Object RecordType -eq 'CostMeter'
        $meter.ComparisonStatus | Should Be 'NotOperationMeter'
        ($null -eq $meter.BilledOperationCount) | Should Be $true
        $meter.ActualCost | Should Be 0.00012
    }

    It 'keeps absent billing meters null instead of reporting zero charges' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Writes' }
        $comparison.ComparisonStatus | Should Be 'NoMatchingBillingMeter'
        ($null -eq $comparison.BilledOperationCount) | Should Be $true
        ($null -eq $comparison.ActualCost) | Should Be $true
    }

    It 'does not assume an operation unit multiplier from cost or meter name' {
        $script:costRows[0].UnitOfMeasure = 'MysteryUnits'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.ComparisonStatus | Should Be 'UnverifiedUnit'
        ($null -eq $comparison.BilledOperationCount) | Should Be $true
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
        $comparisons.Count | Should Be 2
        $comparisons[0].BilledOperationCount | Should Be 3
        $comparisons[1].BilledOperationCount | Should Be 3
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should Be 3
        ($rows | Where-Object ChargeType -eq 'Refund').ComparisonStatus | Should Be 'NonUsageCharge'
    }

    It 'filters billing rows by exact account and usage date' {
        $old = $script:costRows[0].PSObject.Copy()
        $old.Date = $script:end.ToString('yyyy-MM-dd')
        $other = $script:costRows[0].PSObject.Copy()
        $other.ResourceId = $script:id.Replace('testaccount','otheraccount')
        @($script:costRows[0],$old,$other) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should Be 1
        ($rows | Where-Object RecordType -eq 'CostMeter').BilledOperationCount | Should Be 3
    }

    It 'marks comparisons incomplete without losing available billed quantities' {
        $script:missingMetrics = $true
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -WarningAction SilentlyContinue -ErrorAction Stop)
        $comparison = $rows | Where-Object { $_.RecordType -eq 'CostComparison' -and $_.Category -eq 'Reads' }
        $comparison.ComparisonStatus | Should Be 'MetricsIncomplete'
        $comparison.BilledOperationCount | Should Be 3
        ($null -eq $comparison.RequestMinusBilledCount) | Should Be $true
    }

    It 'surfaces cost access failures separately without discarding valid Monitor results' {
        $script:reportFailure = $true
        $errors = @()
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction SilentlyContinue -ErrorVariable errors)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 3
        ($rows | Where-Object RecordType -eq 'CostError').Message | Should Match '403'
        @($errors | Where-Object FullyQualifiedErrorId -like 'StorageCostComparisonFailed*').Count | Should Be 1
        @($rows | Where-Object RecordType -eq 'CostComparison').Count | Should Be 0
    }

    It 'rejects report polling URLs outside the authenticated ARM endpoint' {
        $script:badPollHost = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should Throw 'invalid polling location'
        $script:downloadCalls | Should Be 0
    }

    It 'does not expose signed download URLs in error records' {
        $script:downloadFailure = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction SilentlyContinue)
        $errorRow = $rows | Where-Object RecordType -eq 'CostError'
        $errorRow.Message | Should Match 'download failed'
        $errorRow.Message | Should Not Match 'sig=|secret'
    }

    It 'rejects partial-month or chunk-based cost comparisons before Azure requests' {
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddDays(1) -EndTime $script:end -IncludeCostComparison } | Should Throw 'completed UTC'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -SummaryPeriod Chunk -IncludeCostComparison } | Should Throw 'completed UTC'
        $script:metricCalls | Should Be 0
    }

    It 'retains cost fields when exporting the mixed flat output' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
        $rows | Export-Csv "$TestDrive\comparison.csv" -NoTypeInformation
        $exported = Import-Csv "$TestDrive\comparison.csv"
        ($exported | Where-Object RecordType -eq 'CostMeter').MeterName | Should Be 'Hot Read Operations'
        ($exported | Where-Object RecordType -eq 'CostMeter').ActualCost | Should Be '0.00012'
    }

    It 'supports CSV comparisons under strict mode' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction Stop)
            @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should Be 1
        } finally { Set-StrictMode -Off }
    }

    It 'retains the polling location across subsequent pending responses' {
        $script:pendingPolls = 1
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop)
        $script:pollCalls | Should Be 2
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should Be 1
    }

    It 'bounds polling instead of waiting indefinitely' {
        $script:pendingPolls = 100
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should Throw 'polling limit'
        $script:downloadCalls | Should Be 0
    }

    It 'rejects incomplete report manifests rather than comparing a partial download' {
        $script:badManifest = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCostComparison -ErrorAction Stop } | Should Throw 'every report partition'
        $script:downloadCalls | Should Be 0
    }

    It 'rejects duplicate CSV paths instead of double-counting billed quantities' {
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv @($script:csv,$script:csv) -ErrorAction Stop } | Should Throw 'Duplicate cost CSV'
    }

    It 'reports malformed cost numbers as a cost failure' {
        $script:costRows[0].Quantity = 'invalid'
        $script:costRows | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -ErrorAction SilentlyContinue)
        ($rows | Where-Object RecordType -eq 'CostError').Message | Should Match 'Invalid cost details number'
    }

    It 'excludes unassigned billing charges without invalidating account comparisons' {
        $unassigned = $script:costRows[0].PSObject.Copy()
        $unassigned.ResourceId = ''
        @($script:costRows[0],$unassigned) | Export-Csv $script:csv -NoTypeInformation
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -CostDetailsCsv $script:csv -WarningAction SilentlyContinue -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'CostMeter').Count | Should Be 1
        ($rows | Where-Object RecordType -eq 'CostMeter').BilledOperationCount | Should Be 3
    }
}
