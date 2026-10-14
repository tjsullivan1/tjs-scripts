function Get-AzContext { param([switch]$ListAvailable) }
function Invoke-AzRestMethod { param($Path, $Method, $DefaultProfile) }

Describe 'Historical capacity through Get-AzStorageTransactionMetric' {
    BeforeEach {
        . "$PSScriptRoot\..\Get-AzStorageTransactionMetric.ps1"
        $script:sub = '11111111-1111-1111-1111-111111111111'
        $script:id = "/subscriptions/$script:sub/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/testaccount"
        $script:start = [datetimeoffset]::UtcNow.AddDays(-2)
        $script:start = $script:start.AddTicks(-($script:start.Ticks % [timespan]::TicksPerHour))
        $script:end = $script:start.AddHours(3)
        $script:values = @(100, 300, 500)
        $script:capacityFailure = $false
        $script:mismatch = $false
        $script:emptyCapacity = $false
        $script:hns = $true
        $script:coolValues = $null
        $script:duplicatePoints = $false
        $script:duplicateSeries = $false
        $script:badMetric = $false
        $script:seriesCap = $false
        $script:outOfWindow = $false
        $script:missingDimension = $false
        Mock Get-AzContext {
            [pscustomobject]@{ Subscription = @{ Id = $script:sub; Name = 'Example subscription' } }
        }
        Mock Invoke-AzRestMethod {
            if ($Path -notmatch 'Microsoft.Insights') {
                return [pscustomobject]@{ StatusCode = 200; Content = (@{
                    kind = 'StorageV2'; sku = @{ name = 'Standard_LRS' }; location = 'eastus'
                    properties = @{ isHnsEnabled = $script:hns; accessTier = 'Hot' }
                } | ConvertTo-Json -Depth 5) }
            }
            if ($Path -match 'metricnames=Transactions') {
                $series = if ($Path -match '%24filter=') { @() } else { @(@{ data = @(@{ total = 0 }) }) }
                return [pscustomobject]@{ StatusCode = 200; Content = (@{
                    value = @(@{ name = @{ value = 'Transactions' }; unit = 'Count'; errorCode = 'Success'; timeseries = $series })
                } | ConvertTo-Json -Depth 10) }
            }
            if ($script:capacityFailure) { throw 'Capacity denied' }
            $decoded = [uri]::UnescapeDataString($Path)
            $decoded -match 'timespan=([^&]+)' | Out-Null
            $range = $Matches[1].Split('/')
            $first = [datetimeoffset]$range[0]
            $last = [datetimeoffset]$range[1]
            $metric = if ($Path -match 'metricnames=IndexCapacity') { 'IndexCapacity' } else { 'BlobCapacity' }
            $data = @(
                for ($time = $first; $time -lt $last; $time = $time.AddHours(1)) {
                    $index = [int]($time - $script:start).TotalHours
                    $value = $script:values[$index]
                    if ($metric -eq 'IndexCapacity' -and $null -ne $value) { $value = ($index + 1) * 10 }
                    if ($script:coolValues -and $Path -notmatch '%24filter=' -and $metric -eq 'BlobCapacity') {
                        $value += $script:coolValues[$index]
                    }
                    if ($script:mismatch -and $Path -notmatch '%24filter=' -and $metric -eq 'BlobCapacity') { $value = 999 }
                    @{ timeStamp = $time.ToString('o'); average = $value }
                }
            )
            if ($script:duplicatePoints) { $data += $data[0] }
            if ($script:outOfWindow) { $data[0].timeStamp = $last.ToString('o') }
            $series = @{ data = $data }
            if ($Path -match '%24filter=') {
                $series.metadatavalues = @(
                    @{ name = @{ value = 'Tier' }; value = 'Hot' }
                    @{ name = @{ value = 'BlobType' }; value = 'BlockBlob' }
                )
                if ($script:missingDimension) { $series.metadatavalues = @() }
            }
            $seriesList = @(if (-not $script:emptyCapacity) { $series })
            if ($script:coolValues -and $Path -match '%24filter=') {
                $seriesList += @{
                    metadatavalues = @(
                        @{ name = @{ value = 'Tier' }; value = 'Cool' }
                        @{ name = @{ value = 'BlobType' }; value = 'BlockBlob' }
                    )
                    data = @(
                        for ($time = $first; $time -lt $last; $time = $time.AddHours(1)) {
                            @{ timeStamp = $time.ToString('o'); average = $script:coolValues[[int]($time - $script:start).TotalHours] }
                        }
                    )
                }
            }
            if ($script:duplicateSeries -and $Path -match '%24filter=') { $seriesList += $series }
            if ($script:seriesCap -and $Path -match '%24filter=') { $seriesList = @(1..10000 | ForEach-Object { $series }) }
            [pscustomobject]@{ StatusCode = 200; Content = (@{
                interval = 'PT1H'
                value = @(@{ name = @{ value = $metric }; unit = 'Bytes'; errorCode = $(if ($script:badMetric) { 'BadArgument' } else { 'Success' }); timeseries = $seriesList })
            } | ConvertTo-Json -Depth 12) }
        }
    }

        It 'does not turn missing hours into zero or a complete monthly average' {
            $script:values = @(100, $null, 500)
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -WarningAction SilentlyContinue -ErrorAction Stop)
            $capacity = $rows | Where-Object RecordType -eq 'Capacity'
            ($null -eq $capacity.AverageUsedBytes) | Should Be $true
            $capacity.AverageObservedBytes | Should Be 300
            $capacity.ObservedByteHours | Should Be 600
            $capacity.MissingHours | Should Be 1
            $capacity.CapacityStatus | Should Be 'IncompleteSamples'
        }

        It 'keeps successful empty capacity responses unavailable rather than zero' {
            $script:emptyCapacity = $true
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -WarningAction SilentlyContinue -ErrorAction Stop)
            $capacity = $rows | Where-Object RecordType -eq 'Capacity'
            $capacity.ObservedHours | Should Be 0
            $capacity.MissingHours | Should Be 3
            ($null -eq $capacity.AverageUsedBytes) | Should Be $true
            ($null -eq $capacity.ObservedByteHours) | Should Be $true
        }

        It 'preserves explicitly measured zeros and skips index collection without HNS' {
            $script:values = @(0, 0, 0)
            $script:hns = $false
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop)
            ($rows | Where-Object RecordType -eq 'Capacity').AverageUsedBytes | Should Be 0
            @($rows | Where-Object RecordType -eq 'IndexCapacity').Count | Should Be 0
            Assert-MockCalled Invoke-AzRestMethod -Scope It -Times 0 -ParameterFilter { $Path -match 'metricnames=IndexCapacity' }
        }

        It 'keeps tier quantities distinct and reconciles their hourly sums' {
            $script:coolValues = @(10, 20, 30)
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop)
            ($rows | Where-Object { $_.RecordType -eq 'Capacity' -and $_.Tier -eq 'Cool' }).AverageUsedBytes | Should Be 20
            ($rows | Where-Object { $_.RecordType -eq 'Capacity' -and $_.Tier -eq 'Hot' }).AverageUsedBytes | Should Be 300
            ($rows | Where-Object RecordType -eq 'CapacityAccountTotal').AverageUsedBytes | Should Be 320
        }

        It 'fails capacity reconciliation without discarding transaction results' {
            $script:mismatch = $true
            $errors = @()
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction SilentlyContinue -ErrorVariable errors)
            ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 0
            ($rows | Where-Object RecordType -eq 'CapacityError').Message | Should Match 'does not match unsplit'
            @($rows | Where-Object RecordType -eq 'Capacity').Count | Should Be 0
            @($errors | Where-Object FullyQualifiedErrorId -like 'StorageCapacityCollectionFailed*').Count | Should Be 1
        }

        It 'surfaces capacity HTTP and metric-level failures' {
            $script:capacityFailure = $true
            { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'Capacity denied'
            $script:capacityFailure = $false
            $script:badMetric = $true
            { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'BadArgument'
        }

        It 'rejects duplicate timestamps and dimension series' {
            $script:duplicatePoints = $true
            { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'Duplicate capacity timestamp'
            $script:duplicatePoints = $false
            $script:duplicateSeries = $true
            { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'Duplicate capacity dimension series'
        }

        It 'separates months and excludes the exclusive end boundary' {
            $boundary = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero).AddMonths(-1)
            $script:start = $boundary.AddHours(-1)
            $script:end = $boundary.AddHours(2)
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop)
            $capacity = @($rows | Where-Object RecordType -eq 'Capacity')
            $capacity.Count | Should Be 2
            $capacity[0].AverageUsedBytes | Should Be 100
            $capacity[1].AverageUsedBytes | Should Be 400
            $capacity[0].EndTime | Should Be $boundary.ToString('o')
            $capacity[1].ExpectedHours | Should Be 2
            $capacity[1].IsPartialMonth | Should Be $true
        }

        It 'isolates multiple accounts and exports flat capacity fields under strict mode' {
            Set-StrictMode -Version Latest
            try {
                $other = $script:id.Replace('testaccount', 'otheraccount')
                $rows = @(@($script:id, $other) | Get-AzStorageTransactionMetric -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop)
                $rows | Export-Csv "$TestDrive\capacity.csv" -NoTypeInformation
                $csv = @(Import-Csv "$TestDrive\capacity.csv" | Where-Object RecordType -eq 'Capacity')
                $csv.Count | Should Be 2
                $csv[0].AverageUsedBytes | Should Be '300'
                $csv[0].ResourceId | Should Not Be $csv[1].ResourceId
            } finally { Set-StrictMode -Off }
        }

        It 'does not collect capacity by default and validates hourly boundaries before requests' {
            Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop | Out-Null
            Assert-MockCalled Invoke-AzRestMethod -Scope It -Times 0 -ParameterFilter { $Path -match 'metricnames=BlobCapacity|metricnames=IndexCapacity' }
            { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddMinutes(1) -EndTime $script:end -IncludeCapacity } | Should Throw 'whole hours'
        }
    It 'weights hourly samples rather than averaging unequal query chunks' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 2 -IncludeCapacity -ErrorAction Stop)
        $capacity = $rows | Where-Object RecordType -eq 'Capacity'
        $capacity.AverageUsedBytes | Should Be 300
        $capacity.ObservedByteHours | Should Be 900
        $capacity.ExpectedHours | Should Be 3
        $capacity.ObservedHours | Should Be 3
        $capacity.MissingHours | Should Be 0
        $capacity.Tier | Should Be 'Hot'
        $capacity.BlobType | Should Be 'BlockBlob'
        $capacity.CapacityStatus | Should Be 'CompleteSamples'
        ($rows | Where-Object RecordType -eq 'IndexCapacity').AverageUsedBytes | Should Be 20
        ($rows | Where-Object RecordType -eq 'CapacityAccountTotal').AverageUsedBytes | Should Be 300
        $rows[0].SubscriptionName | Should Be 'Example subscription'
        $rows[0].ConfigurationHistoryStatus | Should Be 'CurrentSnapshotOnly'
        ([datetimeoffset]$rows[0].ConfigurationObservedAtUtc -gt $script:end) | Should Be $true
    }

    It 'fails at the exact series cap rather than accepting potentially truncated capacity' {
        $script:seriesCap = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'top=10000'
    }

    It 'rejects out-of-window samples and missing dimensions' {
        $script:outOfWindow = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'outside the requested hourly window'
        $script:outOfWindow = $false
        $script:missingDimension = $true
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeCapacity -ErrorAction Stop } | Should Throw 'missing Tier or BlobType'
    }

    It 'retains individual capacity query windows when Chunk output is requested' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 2 -SummaryPeriod Chunk -IncludeCapacity -ErrorAction Stop)
        $capacity = @($rows | Where-Object RecordType -eq 'Capacity')
        $capacity.Count | Should Be 2
        $capacity[0].AverageUsedBytes | Should Be 200
        $capacity[0].ExpectedHours | Should Be 2
        $capacity[1].AverageUsedBytes | Should Be 500
        $capacity[1].ExpectedHours | Should Be 1
        $capacity[0].EndTime | Should Be $capacity[1].StartTime
    }
}
