[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Offline Az boundary stubs retain the parameters consumed by Pester mocks.')]
param()

Import-Module "$PSScriptRoot\..\StorageMetrics.psd1" -Force -ErrorAction Stop

InModuleScope StorageMetrics {
# Az commands are external boundaries; these stubs allow offline mocking.
function Get-AzContext { param([switch]$ListAvailable) }
function Invoke-AzRestMethod { param($Path, $Method, $DefaultProfile) }

Describe 'Get-AzStorageTransactionMetric' {
    BeforeEach {
        . "$PSScriptRoot\..\Get-AzStorageTransactionMetric.ps1"
        $script:subscription = '11111111-1111-1111-1111-111111111111'
        $script:id = "/subscriptions/$script:subscription/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/testaccount"
        $script:start = [datetimeoffset]::UtcNow.AddDays(-2)
        $script:start = $script:start.AddTicks(-($script:start.Ticks % [timespan]::TicksPerHour))
        $script:end = $script:start.AddHours(1)
        $script:operations = @(
            @{ Api = 'GetBlob'; Total = 3; Response = 'Success'; Tier = 'Hot' }
        )
        $script:unsplit = 3
        $script:kind = 'StorageV2'
        $script:sku = 'Standard_LRS'
        $script:contexts = @([pscustomobject]@{ Subscription = @{ Id = $script:subscription }; Tenant = @{ Id = 'tenant' } })
        $script:splitBody = $null
        $script:metricBody = $null
        $script:httpFailure = $false
        $script:responseStatuses = @()
        $script:responseStatusIndex = 0
        $script:includeRetryAfter = $true
        $script:capAboveOneHour = $false
        $script:mismatchAboveOneHour = $false
        $script:badAccount = $false
        $script:splitCalls = 0
        $script:failSecondChunk = $false
        $script:missingSecondChunk = $false
        Mock Start-Sleep -ModuleName StorageMetrics {}
        Mock Get-AzContext -ModuleName StorageMetrics {
            $script:contexts
        }
        Mock Invoke-AzRestMethod -ModuleName StorageMetrics {
            if ($script:httpFailure) { return [pscustomobject]@{ StatusCode = 403; Content = 'Forbidden' } }
            if ($script:badAccount -and $Path -match '/badaccount[/?]') { throw 'Account denied' }
            if ($Path -notmatch 'Microsoft.Insights') {
                return [pscustomobject]@{ StatusCode = 200; Content = (@{
                    kind = $script:kind; sku = @{ name = $script:sku }
                    location = 'eastus'; properties = @{ isHnsEnabled = $true; accessTier = 'Hot' }
                } | ConvertTo-Json -Depth 10) }
            }
            if ($script:responseStatusIndex -lt $script:responseStatuses.Count) {
                $status = $script:responseStatuses[$script:responseStatusIndex]
                $script:responseStatusIndex++
                if ($status -ne 200) {
                    $transient = [pscustomobject]@{ StatusCode = $status; Content = 'Transient response' }
                    if ($script:includeRetryAfter) { $transient | Add-Member -NotePropertyName Headers -NotePropertyValue @{ 'Retry-After' = '0' } }
                    return $transient
                }
            }
            if ($script:metricBody) { return [pscustomobject]@{ StatusCode = 200; Content = $script:metricBody } }
            $decoded = [uri]::UnescapeDataString($Path)
            $windowMatch = [regex]::Match($decoded, 'timespan=([^&]+)')
            $window = $windowMatch.Groups[1].Value.Split('/')
            $windowHours = ([datetimeoffset]$window[1] - [datetimeoffset]$window[0]).TotalHours
            $series = @()
            if ($Path -match '%24filter=') {
                $script:splitCalls++
                if ($script:failSecondChunk -and $script:splitCalls -eq 2) { throw 'Second chunk failed' }
                if ($script:splitBody) { return [pscustomobject]@{ StatusCode = 200; Content = $script:splitBody } }
                if ($script:capAboveOneHour -and $windowHours -gt 1) {
                    $content = @{
                        value = @(@{ name = @{ value = 'Transactions' }; unit = 'Count'
                            errorCode = 'Success'; timeseries = @(1..10000 | ForEach-Object { @{ data = @() } }) })
                    } | ConvertTo-Json -Depth 10
                    return [pscustomobject]@{ StatusCode = 200; Content = $content }
                }
                foreach ($op in $script:operations) {
                    $series += @{
                        metadatavalues = @(
                            @{ name = @{ value = 'ApiName' }; value = $op.Api }
                            @{ name = @{ value = 'ResponseType' }; value = $op.Response }
                            @{ name = @{ value = 'Tier' }; value = $op.Tier }
                            @{ name = @{ value = 'GeoType' }; value = 'Primary' }
                            @{ name = @{ value = 'Authentication' }; value = 'OAuth' }
                            @{ name = @{ value = 'TransactionType' }; value = 'User' }
                        )
                        data = @(@{ total = $op.Total })
                    }
                }
            } else {
                $unsplit = $script:unsplit
                if ($script:mismatchAboveOneHour -and $windowHours -gt 1) { $unsplit++ }
                $series = @(@{ data = @(@{ total = $unsplit }) })
            }
            if ($script:missingSecondChunk -and $script:splitCalls -eq 2) {
                $series[0].data[0].total = $null
            }
            [pscustomobject]@{ StatusCode = 200; Content = (@{
                value = @(@{ name = @{ value = 'Transactions' }; unit = 'Count'
                    errorCode = 'Success'; timeseries = $series })
            } | ConvertTo-Json -Depth 15) }
        }
    }

    It 'adds a display type without adding exported properties' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        foreach ($row in $rows) {
            $row.PSObject.TypeNames[0] | Should Be "StorageMetrics.$($row.RecordType)"
            @($row.PSObject.Properties.Name | Where-Object { $_ -in @('PSTypeName', 'PSTypeNames') }).Count | Should Be 0
        }
    }

    It 'keeps the established ordered collector export schema' {
        $expected = @'
RecordType SubscriptionId SubscriptionName ResourceGroupName StorageAccountName ResourceId MetricResourceId
Location AccountKind SkuName IsHnsEnabled AccountDefaultAccessTier PrimaryLocation SecondaryLocation IsSftpEnabled
IsNfsV3Enabled ConfigurationObservedAtUtc ConfigurationHistoryStatus StartTime EndTime SummaryPeriod Month
IsPartialMonth Category ApiName ResponseType Tier GeoType Authentication TransactionType RequestCount CountStatus
CompletenessStatus MappingStatus QueryAccelerationDataScannedBytes QueryAccelerationDataReturnedBytes
QueryAccelerationStatus QueryWindowHours Message BilledQuantity UnitOfMeasure BilledOperationCount
RequestMinusBilledCount ActualCost Currency MeterId MeterName MeterSubCategory ProductName ChargeType CostSource
ComparisonStatus MetricName BlobType AverageUsedBytes AverageObservedBytes ObservedByteHours ExpectedHours
ObservedHours MissingHours CapacityStatus CapacityReconciliationStatus QuantityBasis BillingUsageDate MeterRegion
BillingResourceLocation MeterCategory ConsumedService PublisherType ProductId PricingModel ReservationId BenefitId
EffectivePrice UnitPrice PayGPrice PricingCurrency ExchangeRatePricingToBilling ChargeFrequency CostAllocationRuleName
InvoiceId BillingPeriodStartDate BillingPeriodEndDate ServicePeriodStartDate ServicePeriodEndDate BillingCoverageStatus
BillingTier BillingRedundancy BillingQuantityKind NormalizedBilledQuantity NormalizedBilledUnit BillingMappingStatus
HasNegativeUsageQuantity SourceRecordType QuantityKind Quantity QuantityUnit QuantitySource QuantityStatus
ObservedCapacityGiBMonth BilledCapacityGiBMonth CapacityDifferenceGiBMonth CapacityDifferencePercent CapacityTierBasis
CurrentUsedBytes CurrentUsedGiB CapacitySampleTimeUtc CapacitySampleAgeHours
'@
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        ($rows[0].PSObject.Properties.Name -join ',') | Should Be (($expected -split '\s+') -join ',')
    }

    It 'uses the imported policy across repeated calls without rereading its data file' {
        Mock Import-PowerShellDataFile -ModuleName StorageMetrics { throw 'Unexpected policy reload' }
        $first = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        $script:operations = @(@{ Api = 'PutBlob'; Total = 5; Response = 'Success'; Tier = 'Hot' })
        $script:unsplit = 5
        $second = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        ($first | Where-Object RecordType -eq 'Detail').Category | Should Be 'Reads'
        ($second | Where-Object RecordType -eq 'Detail').Category | Should Be 'Writes'
        ($second | Where-Object RecordType -eq 'Detail').RequestCount | Should Be 5
        Assert-MockCalled Import-PowerShellDataFile -ModuleName StorageMetrics -Scope It -Times 0
    }

    It 'preserves null optional identity metadata when the saved context omits it' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        ($null -eq $rows[0].SubscriptionName) | Should Be $true
    }

    It 'preserves known subscription identity and unknown configuration on account read failures' {
        $script:contexts[0].Subscription.Name = 'Known subscription'
        $script:httpFailure = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction SilentlyContinue)
        $rows.Count | Should Be 1
        $rows[0].SubscriptionName | Should Be 'Known subscription'
        ($null -eq $rows[0].ConfigurationObservedAtUtc) | Should Be $true
        $rows[0].PSObject.TypeNames[0] | Should Be 'StorageMetrics.Error'
    }

    It 'returns a measured read summary and auditable dimensions' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        ($rows | Where-Object { $_.RecordType -eq 'Summary' -and $_.Category -eq 'Reads' }).RequestCount | Should Be 3
        $detail = $rows | Where-Object RecordType -eq 'Detail'
        $detail.ApiName | Should Be 'GetBlob'
        $detail.ResponseType | Should Be 'Success'
        $detail.Tier | Should Be 'Hot'
        $detail.CompletenessStatus | Should Be 'Reconciled'
    }

    It 'sends UTC Z timestamps so form decoding cannot replace offset plus signs with spaces' {
        Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop | Out-Null
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 2 -Exactly -ParameterFilter {
            $Path -match 'Microsoft.Insights' -and
            [uri]::UnescapeDataString($Path) -match 'timespan=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/' -and
            [uri]::UnescapeDataString($Path) -notmatch '\+00:00'
        }
    }

    It 'uses documented Blob and Data Lake names instead of verb heuristics' {
        $expected = @{
            Reads = 'GetBlob QueryBlobContents GetFileProperties GetPathAccessControl GetPathStatus ReadFile'
            Writes = 'SealBlob AppendBlockThroughCopy AppendBlock CopyBlobFromURL CopyBlob PutBlobFromURL PutBlob PutBlockFromURL PutBlockList PutBlock UndeleteBlob CreateFilesystem SetFilesystemProperties CreatePathDir CreatePathFile AppendFile FlushFile SetFileProperties SetPathAccessControl'
            IterativeReads = 'ListFilesystems ListFilesystemDir ListFilesystemFile'
            IterativeWrites = 'RenamePathDir RenamePathFile SetPathAccessControlRecursive'
            ListAndCreateContainer = 'CreateContainer FindBlobsByTags ListBlobs ListContainers RestoreContainer'
            Free = 'DeleteBlob DeleteContainer DeleteFilesystem DeleteDirectory DeleteFile'
            AllOtherOperations = 'AbortCopyBlob SetContainerServiceMetadata GetAccountInformation GetBlobMetadata GetBlobProperties GetBlobServiceProperties GetBlobServiceStats GetBlobTags GetBlockList GetContainerACL GetContainerMetadata GetContainerProperties GetUserDelegationKey IncrementalCopyBlob AcquireBlobLease ReleaseBlobLease RenewBlobLease BreakBlobLease ChangeBlobLease AcquireContainerLease ReleaseContainerLease RenewContainerLease BreakContainerLease ChangeContainerLease BlobPreflightRequest SetBlobExpiry SetBlobMetadata SetBlobProperties SetBlobServiceProperties SetBlobTags SetContainerACL SetContainerMetadata SnapshotBlob GetFilesystemProperties LeaseFile'
        }
        $script:operations = @(
            foreach ($names in $expected.Values) {
                foreach ($api in $names.Split(' ')) { @{ Api = $api; Total = 1; Response = 'Success'; Tier = 'Hot' } }
            }
        )
        $script:unsplit = $script:operations.Count
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail -ErrorAction Stop)
        foreach ($category in $expected.Keys) {
            foreach ($api in $expected[$category].Split(' ')) {
                ($rows | Where-Object { $_.RecordType -eq 'Detail' -and $_.ApiName -eq $api }).Category | Should Be $category
            }
        }
    }

    It 'keeps unknown and ambiguous APIs out of AllOtherOperations' {
        $script:operations = @(
            @{ Api = 'GetNewApi'; Total = 2; Response = 'Success'; Tier = 'Hot' }
            @{ Api = 'SetBlobTier'; Total = 5; Response = 'Success'; Tier = 'Cool' }
        )
        $script:unsplit = 7
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        ($rows | Where-Object { $_.RecordType -eq 'Summary' -and $_.Category -eq 'Unmapped' }).RequestCount | Should Be 7
        ($rows | Where-Object { $_.RecordType -eq 'Summary' -and $_.Category -eq 'AllOtherOperations' }).RequestCount | Should Be 0
        ($rows | Where-Object ApiName -eq 'SetBlobTier').MappingStatus | Should Be 'AmbiguousTierChangeOrBatch'
    }

    It 'honors the general purpose v1 column' {
        $script:kind = 'Storage'
        $script:operations = @(
            @{ Api = 'GetBlobProperties'; Total = 4; Response = 'Success'; Tier = 'Hot' }
            @{ Api = 'AbortCopyBlob'; Total = 2; Response = 'Success'; Tier = 'Hot' }
            @{ Api = 'DeleteBlob'; Total = 3; Response = 'Success'; Tier = 'Hot' }
        )
        $script:unsplit = 9
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        ($rows | Where-Object ApiName -eq 'GetBlobProperties').Category | Should Be 'Reads'
        ($rows | Where-Object ApiName -eq 'AbortCopyBlob').Category | Should Be 'Writes'
        ($rows | Where-Object ApiName -eq 'DeleteBlob').Category | Should Be 'AllOtherOperations'
    }

    It 'supports the premium block blob column and preserves configuration' {
        $script:kind = 'BlockBlobStorage'
        $script:sku = 'Premium_LRS'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        $rows[0].AccountKind | Should Be 'BlockBlobStorage'
        $rows[0].SkuName | Should Be 'Premium_LRS'
        $rows[0].IsHnsEnabled | Should Be $true
        $rows[0].AccountDefaultAccessTier | Should Be 'Hot'
    }

    It 'does not silently apply a documented column to legacy BlobStorage' {
        $script:kind = 'BlobStorage'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail -WarningAction SilentlyContinue)
        ($rows | Where-Object RecordType -eq 'Detail').MappingStatus | Should Be 'UnsupportedAccount'
        ($rows | Where-Object { $_.RecordType -eq 'Summary' -and $_.Category -eq 'Unmapped' }).RequestCount | Should Be 3
    }

    It 'preserves failed requests and aggregates separate response and tier series' {
        $script:operations = @(
            @{ Api = 'GetBlob'; Total = 3; Response = 'Success'; Tier = 'Hot' }
            @{ Api = 'GetBlob'; Total = 2; Response = 'AuthenticationError'; Tier = 'Cool' }
            @{ Api = 'PutBlob'; Total = 7; Response = 'AuthorizationError'; Tier = 'Hot' }
        )
        $script:unsplit = 12
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        ($rows | Where-Object { $_.RecordType -eq 'Summary' -and $_.Category -eq 'Reads' }).RequestCount | Should Be 5
        ($rows | Where-Object ResponseType -eq 'AuthenticationError').RequestCount | Should Be 2
        ($rows | Where-Object ResponseType -eq 'AuthenticationError').Tier | Should Be 'Cool'
    }

    It 'represents unavailable query acceleration bytes as null rather than traffic bytes' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        ($null -eq $rows[0].QueryAccelerationDataScannedBytes) | Should Be $true
        ($null -eq $rows[0].QueryAccelerationDataReturnedBytes) | Should Be $true
        $rows[0].QueryAccelerationStatus | Should Be 'UnavailableInPlatformMetrics'
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 0 -ParameterFilter { $Path -match 'Ingress|Egress|QueryAcceleration' }
    }

    It 'distinguishes a genuine zero from missing data' {
        $script:operations = @()
        $script:unsplit = 0
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        ($rows | Where-Object Category -eq 'Reads').RequestCount | Should Be 0
        $rows[0].CompletenessStatus | Should Be 'Reconciled'
    }

    It 'makes summaries null when an unsplit Total is missing' {
        $script:unsplit = $null
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -WarningAction SilentlyContinue)
        ($null -eq ($rows | Where-Object Category -eq 'Reads').RequestCount) | Should Be $true
        $rows[0].CountStatus | Should Be 'MissingData'
        $rows[0].CompletenessStatus | Should Be 'UnverifiableMissingData'
    }

    It 'does not turn a null split Total into zero' {
        $script:operations[0].Total = $null
        $script:unsplit = 0
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail -WarningAction SilentlyContinue)
        ($null -eq ($rows | Where-Object Category -eq 'Writes').RequestCount) | Should Be $true
        ($rows | Where-Object RecordType -eq 'Detail').CountStatus | Should Be 'MissingData'
    }

    It 'keeps an empty metric response without explicit Success unknown' {
        $script:operations = @()
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","timeseries":[]}]}'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -WarningAction SilentlyContinue)
        ($null -eq $rows[0].RequestCount) | Should Be $true
        @($rows | Where-Object { $_.RecordType -eq 'Summary' -and $null -ne $_.RequestCount }).Count | Should Be 0
        $rows[0].CompletenessStatus | Should Be 'UnverifiableMissingData'
    }

    It 'reports zero when Azure explicitly returns Success with empty timeseries' {
        $script:operations = @()
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","errorCode":"Success","timeseries":[]}]}'
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        $rows[0].RequestCount | Should Be 0
        $rows[0].CompletenessStatus | Should Be 'Reconciled'
    }

    It 'preserves missing-data semantics when the caller uses strict mode' {
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","timeseries":[]}]}'
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -WarningAction SilentlyContinue -ErrorAction Stop)
            $rows[0].CompletenessStatus | Should Be 'UnverifiableMissingData'
        } finally {
            Set-StrictMode -Off
        }
    }

    It 'still emits a flat error record for a denied account under strict mode' {
        $script:httpFailure = $true
        Set-StrictMode -Version Latest
        try {
            $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction SilentlyContinue)
            $rows.Count | Should Be 1
            $rows[0].RecordType | Should Be 'Error'
            ($null -eq $rows[0].SkuName) | Should Be $true
        } finally {
            Set-StrictMode -Off
        }
    }

    It 'exports flat records without losing dimensions or JSON nulls' {
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -IncludeDetail)
        $rows | Export-Csv -LiteralPath "$TestDrive\metrics.csv" -NoTypeInformation
        $csv = @(Import-Csv -LiteralPath "$TestDrive\metrics.csv")
        ($csv | Where-Object RecordType -eq 'Detail').ApiName | Should Be 'GetBlob'
        ($csv | Where-Object RecordType -eq 'Detail').RequestCount | Should Be '3'
        $json = @(ConvertTo-Json -InputObject $rows -Depth 4 | ConvertFrom-Json)
        ($null -eq $json[0].QueryAccelerationDataScannedBytes) | Should Be $true
        ($json | Where-Object RecordType -eq 'Detail').RequestCount | Should Be 3
    }

    It 'fails closed when split and unsplit totals do not reconcile' {
        $script:unsplit = 4
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'does not match unsplit'
    }

    It 'fails closed at the explicit top limit even if hidden series could be zero' {
        $script:splitBody = @{
            value = @(@{ name = @{ value = 'Transactions' }; unit = 'Count'; errorCode = 'Success'
                timeseries = @(1..10000 | ForEach-Object { @{ data = @() } }) })
        } | ConvertTo-Json -Depth 10 -Compress
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'top=10000'
    }

    It 'retries a throttled request and succeeds when the next response is successful' {
        $script:responseStatuses = @(429, 200)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 3
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 3 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
        Assert-MockCalled Start-Sleep -ModuleName StorageMetrics -Scope It -Times 1 -Exactly
        Assert-MockCalled Start-Sleep -ModuleName StorageMetrics -Scope It -Times 1 -Exactly -ParameterFilter { $Seconds -eq 0 }
    }

    It 'retries all supported server errors with exponential jitter when Retry-After is absent' {
        $script:responseStatuses = @(500, 502, 503, 504, 200)
        $script:includeRetryAfter = $false
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 3
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 6 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
        Assert-MockCalled Start-Sleep -ModuleName StorageMetrics -Scope It -Times 4 -Exactly -ParameterFilter { $Seconds -gt 0 }
    }

    It 'stops retrying repeated throttling and emits one account error' {
        $script:responseStatuses = @(429, 429, 429)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end `
            -MaxRetry 2 -ErrorAction SilentlyContinue)
        $rows.Count | Should Be 1
        $rows[0].RecordType | Should Be 'Error'
        $rows[0].Message | Should Match '429'
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 3 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
        Assert-MockCalled Start-Sleep -ModuleName StorageMetrics -Scope It -Times 2 -Exactly
    }

    It 'does not retry a forbidden request' {
        $script:responseStatuses = @(403)
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw '403'
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 1 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
        Assert-MockCalled Start-Sleep -ModuleName StorageMetrics -Scope It -Times 0
    }

    It 'rejects recent data before making requests unless explicitly allowed' {
        $script:end = [datetimeoffset]::UtcNow.AddHours(-2)
        $script:end = $script:end.AddTicks(-($script:end.Ticks % [timespan]::TicksPerMinute))
        $script:start = $script:end.AddHours(-1)
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end } |
            Should Throw 'three hours'
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 0
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -AllowRecentData -ErrorAction Stop)
        ($rows | Where-Object RecordType -eq 'AccountTotal').RequestCount | Should Be 3
    }

    It 'uses the requested large window when split and unsplit totals reconcile' {
        $script:end = $script:start.AddHours(4)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end `
            -ChunkHours 744 -SummaryPeriod Chunk -ErrorAction Stop)
        $total = $rows | Where-Object RecordType -eq 'AccountTotal'
        $total.RequestCount | Should Be 3
        $total.QueryWindowHours | Should Be 4
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 1 -Exactly -ParameterFilter {
            $Path -match 'Microsoft.Insights' -and $Path -match 'top=10000'
        }
    }

    It 'halves a transaction window when the series cap is reached' {
        $script:end = $script:start.AddHours(4)
        $script:capAboveOneHour = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end `
            -ChunkHours 4 -SummaryPeriod Chunk -ErrorAction Stop)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals.Count | Should Be 4
        @($totals | Where-Object QueryWindowHours -ne 1).Count | Should Be 0
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 7 -Exactly -ParameterFilter {
            $Path -match 'Microsoft.Insights' -and $Path -match 'top=10000'
        }
    }

    It 'halves a transaction window when split totals do not reconcile' {
        $script:end = $script:start.AddHours(2)
        $script:mismatchAboveOneHour = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end `
            -ChunkHours 2 -SummaryPeriod Chunk -ErrorAction Stop)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals.Count | Should Be 2
        @($totals | Where-Object QueryWindowHours -ne 1).Count | Should Be 0
    }

    It 'requires all requested dimensions' {
        $script:splitBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","timeseries":[{"metadatavalues":[],"data":[{"total":3}]}]}]}'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'missing dimension'
    }

    It 'rejects duplicate dimension series instead of double counting' {
        $script:operations += $script:operations[0]
        $script:unsplit = 6
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'Duplicate'
    }

    It 'surfaces metric-level errors even on HTTP success' {
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","errorCode":"BadArgument","errorMessage":"invalid filter","timeseries":[]}]}'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'BadArgument'
    }

    It 'rejects malformed JSON, missing metrics and incorrect metric units' {
        $script:metricBody = 'not-json'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'JSON'
        $script:metricBody = '{"value":[]}'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'exactly one'
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Bytes","timeseries":[]}]}'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'Count units'
    }

    It 'rejects invalid request totals and unexpected point cardinality' {
        $script:operations[0].Total = -1
        $script:unsplit = -1
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'nonnegative integer'
        $script:operations[0].Total = 1.5
        $script:unsplit = 1.5
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'nonnegative integer'
        $script:metricBody = '{"value":[{"name":{"value":"Transactions"},"unit":"Count","timeseries":[{"data":[{"total":1},{"total":2}]}]}]}'
        # Both queries have the same unexpected shape; the unsplit total is checked first.
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'single FULL'
    }

    It 'surfaces HTTP failures with an error-stream message and a null error record' {
        $script:httpFailure = $true
        $errors = @()
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction SilentlyContinue -ErrorVariable errors)
        @($errors | Where-Object FullyQualifiedErrorId -like 'StorageTransactionCollectionFailed*').Count | Should Be 1
        $rows.Count | Should Be 1
        $rows[0].RecordType | Should Be 'Error'
        ($null -eq $rows[0].RequestCount) | Should Be $true
        $rows[0].Message | Should Match '403'
    }

    It 'isolates an account failure while continuing other accounts' {
        $script:badAccount = $true
        $bad = $script:id.Replace('testaccount', 'badaccount')
        $rows = @(@($bad, $script:id) | Get-AzStorageTransactionMetric -StartTime $script:start -EndTime $script:end -ErrorAction SilentlyContinue)
        @($rows | Where-Object RecordType -eq 'Error').Count | Should Be 1
        ($rows | Where-Object { $_.StorageAccountName -eq 'testaccount' -and $_.Category -eq 'Reads' }).RequestCount | Should Be 3
    }

    It 'uses explicit contexts for multiple subscriptions without modifying Azure context' {
        $secondSubscription = '22222222-2222-2222-2222-222222222222'
        $script:contexts = @(
            [pscustomobject]@{ Subscription = @{ Id = $script:subscription } }
            [pscustomobject]@{ Subscription = @{ Id = '22222222-2222-2222-2222-222222222222' } }
        )
        $second = $script:id.Replace($script:subscription, $secondSubscription)
        $rows = @(@($script:id, $second, $script:id) | Get-AzStorageTransactionMetric -StartTime $script:start -EndTime $script:end -ErrorAction Stop)
        @($rows | Where-Object RecordType -eq 'AccountTotal').Count | Should Be 2
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 3 -Exactly -ParameterFilter {
            $Path -match '/subscriptions/22222222-' -and $DefaultProfile.Subscription.Id -eq '22222222-2222-2222-2222-222222222222'
        }
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 0 -ParameterFilter {
            $Path -match 'Microsoft.Insights' -and $Path -notmatch '/blobServices/default/'
        }
    }

    It 'surfaces missing and ambiguous saved subscription contexts' {
        $script:contexts = @()
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'No saved Az context'
        $script:contexts = @(
            [pscustomobject]@{ Subscription = @{ Id = $script:subscription } }
            [pscustomobject]@{ Subscription = @{ Id = $script:subscription } }
        )
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'Multiple saved Az contexts'
    }

    It 'chunks adjacent windows without overlapping or summing account-parent metrics' {
        $script:end = $script:start.AddHours(3)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 2 -SummaryPeriod Chunk)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals.Count | Should Be 2
        $totals[0].EndTime | Should Be $totals[1].StartTime
        $totals[1].EndTime | Should Be $script:end.ToString('o')
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 2 -Exactly -ParameterFilter {
            $Path -match 'aggregation=Total&interval=FULL' -and $Path -match 'top=10000'
        }
    }

    It 'defaults to monthly totals and merges identical detail dimensions across chunks' {
        $script:start = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero).AddMonths(-1)
        $script:end = $script:start.AddHours(3)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 1 -IncludeDetail)
        $rows.Count | Should Be 10
        $total = $rows | Where-Object RecordType -eq 'AccountTotal'
        $total.RequestCount | Should Be 9
        $total.SummaryPeriod | Should Be 'Month'
        $total.Month | Should Be $script:start.ToString('yyyy-MM')
        $total.IsPartialMonth | Should Be $true
        $total.StartTime | Should Be $script:start.ToString('o')
        $total.EndTime | Should Be $script:end.ToString('o')
        ($rows | Where-Object RecordType -eq 'Detail').RequestCount | Should Be 9
        ($rows | Where-Object Category -eq 'Reads' | Where-Object RecordType -eq 'Summary').RequestCount | Should Be 9
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 6 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
    }

    It 'splits queries at UTC month boundaries even when ChunkHours would cross them' {
        $boundary = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero).AddMonths(-1)
        $script:start = $boundary.AddHours(-1)
        $script:end = $boundary.AddHours(1)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.ToOffset([timespan]::FromHours(-5)) -EndTime $script:end -IncludeDetail)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals.Count | Should Be 2
        $totals[0].Month | Should Be $script:start.ToString('yyyy-MM')
        $totals[1].Month | Should Be $boundary.ToString('yyyy-MM')
        $totals[0].EndTime | Should Be $boundary.ToString('o')
        $totals[1].StartTime | Should Be $boundary.ToString('o')
        $totals[0].RequestCount | Should Be 3
        $totals[1].RequestCount | Should Be 3
        Assert-MockCalled Invoke-AzRestMethod -ModuleName StorageMetrics -Scope It -Times 4 -Exactly -ParameterFilter { $Path -match 'Microsoft.Insights' }
    }

    It 'marks a complete calendar month and excludes the next month at an exclusive end' {
        $script:end = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero)
        $script:start = $script:end.AddMonths(-1)
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end)
        $rows.Count | Should Be 9
        $rows[0].IsPartialMonth | Should Be $false
        $rows[0].RequestCount | Should Be (3 * ($script:end - $script:start).TotalDays)
        $rows[0].EndTime | Should Be $script:end.ToString('o')
    }

    It 'does not hide a missing chunk in monthly totals or category summaries' {
        $script:end = $script:start.AddHours(2)
        $script:missingSecondChunk = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 1 -IncludeDetail -WarningAction SilentlyContinue)
        $rows.Count | Should Be 10
        ($null -eq $rows[0].RequestCount) | Should Be $true
        @($rows | Where-Object { $_.RecordType -eq 'Summary' -and $null -ne $_.RequestCount }).Count | Should Be 0
        ($null -eq ($rows | Where-Object RecordType -eq 'Detail').RequestCount) | Should Be $true
        @($rows | Where-Object CompletenessStatus -ne 'UnverifiableMissingData').Count | Should Be 0
    }

    It 'keeps monthly details separated by tier and response type' {
        $script:end = $script:start.AddHours(2)
        $script:operations += @{ Api = 'GetBlob'; Total = 2; Response = 'AuthenticationError'; Tier = 'Cool' }
        $script:unsplit = 5
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 1 -IncludeDetail)
        @($rows | Where-Object RecordType -eq 'Detail').Count | Should Be 2
        ($rows | Where-Object ApiName -eq 'GetBlob' | Where-Object Tier -eq 'Cool').RequestCount | Should Be 4
        $rows[0].RequestCount | Should Be 10
    }

    It 'never combines monthly counts across accounts' {
        $script:end = $script:start.AddHours(2)
        $other = $script:id.Replace('testaccount', 'otheraccount')
        $rows = @(@($script:id, $other) | Get-AzStorageTransactionMetric -StartTime $script:start -EndTime $script:end -ChunkHours 1)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals.Count | Should Be 2
        $totals[0].RequestCount | Should Be 6
        $totals[1].RequestCount | Should Be 6
        $totals[0].ResourceId | Should Not Be $totals[1].ResourceId
    }

    It 'keeps an incomplete month from affecting another month' {
        $boundary = [datetimeoffset]::new([datetime]::UtcNow.Year, [datetime]::UtcNow.Month, 1, 0, 0, 0, [timespan]::Zero).AddMonths(-1)
        $script:start = $boundary.AddHours(-1)
        $script:end = $boundary.AddHours(1)
        $script:missingSecondChunk = $true
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -WarningAction SilentlyContinue)
        $totals = @($rows | Where-Object RecordType -eq 'AccountTotal')
        $totals[0].CompletenessStatus | Should Be 'Reconciled'
        $totals[0].RequestCount | Should Be 3
        $totals[1].CompletenessStatus | Should Be 'UnverifiableMissingData'
        ($null -eq $totals[1].RequestCount) | Should Be $true
    }

    It 'preserves exact integer counts larger than floating-point precision' {
        $script:end = $script:start.AddHours(2)
        $script:operations[0].Total = [long]9007199254740993
        $script:unsplit = [long]9007199254740993
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 1)
        ($rows[0].RequestCount -eq [decimal]18014398509481986) | Should Be $true
    }

    It 'does not emit partial account results when a later chunk fails' {
        $script:end = $script:start.AddHours(2)
        $script:failSecondChunk = $true
        $script:operations = @()
        $script:unsplit = 0
        $rows = @(Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 1 -ErrorAction SilentlyContinue)
        $rows.Count | Should Be 1
        $rows[0].RecordType | Should Be 'Error'
    }

    It 'rejects Files scope and service IDs' {
        $script:kind = 'FileStorage'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ErrorAction Stop } |
            Should Throw 'outside Blob/ADLS'
        { Get-AzStorageTransactionMetric -ResourceId "$script:id/blobServices/default" -StartTime $script:start -EndTime $script:end } |
            Should Throw 'ARM resource ID'
    }

    It 'validates time ranges, retention, minute alignment and chunk size' {
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:end -EndTime $script:start } | Should Throw 'precede'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime ([datetimeoffset]::UtcNow.AddDays(1)) } | Should Throw 'future'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddSeconds(1) -EndTime $script:end } | Should Throw 'whole minutes'
        { Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start.AddDays(-94) -EndTime $script:end } | Should Throw 'retention'
    }

    It 'rejects a zero-hour chunk at parameter binding' {
        $rejected = $false
        try {
            Get-AzStorageTransactionMetric -ResourceId $script:id -StartTime $script:start -EndTime $script:end -ChunkHours 0 -ErrorAction Stop
        } catch [System.Management.Automation.ParameterBindingException] {
            $rejected = $true
        }
        $rejected | Should Be $true
    }
}
}
