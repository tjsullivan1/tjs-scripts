#Requires -Version 7.0

function Get-AzStorageTransactionMetric {
    <#
    .SYNOPSIS
    Groups observed Blob/ADLS requests into documented operation categories.
    .DESCRIPTION
    Uses Azure Monitor Transactions (Total) on blobServices/default, with existing
    Az contexts. Returns flat objects, not prices or exact billed operations.
    Split series are reconciled with an unsplit service total for each time chunk.
    No storage keys, diagnostic settings, or Azure context changes are used.
    .PARAMETER ResourceId
    Explicit storage account ARM IDs, potentially from multiple subscriptions.
    Accepts strings through the pipeline. Duplicate IDs are collected only once.
    .PARAMETER StartTime
    Inclusive start with an explicit offset, aligned to a whole minute.
    .PARAMETER EndTime
    Exclusive end with an explicit offset, aligned to a whole minute.
    .PARAMETER ChunkHours
    Query window size (1 to 24 hours). Defaults to 24. Reduce for high cardinality.
    .PARAMETER IncludeDetail
    Includes each API/response/tier/authentication/geo/transaction-type series.
    Filter RecordType before summing: Detail, Summary and AccountTotal overlap.
    .EXAMPLE
    . .\PowerShell\Get-AzStorageTransactionMetric.ps1
    $ids | Get-AzStorageTransactionMetric -StartTime '2026-10-01T00:00:00Z' -EndTime '2026-10-02T00:00:00Z' -IncludeDetail
    .OUTPUTS
    System.Management.Automation.PSCustomObject
    .NOTES
    Requires PowerShell 7 and Az.Accounts. See StorageTransactionMetrics.md for
    mappings, RBAC, missing-data semantics, and query acceleration limitations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ResourceId,

        [Parameter(Mandatory)]
        [datetimeoffset]$StartTime,

        [Parameter(Mandatory)]
        [datetimeoffset]$EndTime,

        [ValidateRange(1, 24)]
        [int]$ChunkHours = 24,

        [switch]$IncludeDetail
    )

    begin {
        $start = $StartTime.ToUniversalTime()
        $end = $EndTime.ToUniversalTime()
        if ($start -ge $end -or $end -gt [datetimeoffset]::UtcNow) {
            throw 'StartTime must precede EndTime; EndTime cannot be in the future.'
        }
        if ($start.Ticks % [timespan]::TicksPerMinute -or $end.Ticks % [timespan]::TicksPerMinute) {
            throw 'StartTime and EndTime must be aligned to whole minutes.'
        }
        if ($start -lt [datetimeoffset]::UtcNow.AddDays(-93)) {
            throw 'StartTime is outside the 93-day Azure Monitor platform metric retention window.'
        }
        $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $contexts = @(Get-AzContext -ListAvailable -ErrorAction Stop)
        $categories = @('Reads', 'Writes', 'IterativeReads', 'IterativeWrites',
            'AllOtherOperations', 'ListAndCreateContainer', 'Free', 'Unmapped')

        # Logged names, not REST display names or Get*/Put* heuristics.
        # Source: Microsoft Learn map-rest-apis-transaction-categories, 2026-10-14.
        $blobMap = @{}
        $blobGroups = @{
            Reads = @('GetBlob', 'QueryBlobContents')
            Writes = @('SealBlob', 'AppendBlockThroughCopy', 'AppendBlock', 'CopyBlobFromURL',
                'CopyBlob', 'PutBlobFromURL', 'PutBlob', 'PutBlockFromURL', 'PutBlockList',
                'PutBlock', 'UndeleteBlob')
            ListAndCreateContainer = @('CreateContainer', 'FindBlobsByTags', 'ListBlobs',
                'ListContainers', 'RestoreContainer')
            Free = @('DeleteBlob', 'DeleteContainer')
            AllOtherOperations = @('AbortCopyBlob', 'SetContainerServiceMetadata',
                'GetAccountInformation', 'GetBlobMetadata', 'GetBlobProperties',
                'GetBlobServiceProperties', 'GetBlobServiceStats', 'GetBlobTags',
                'GetBlockList', 'GetContainerACL', 'GetContainerMetadata',
                'GetContainerProperties', 'GetUserDelegationKey', 'IncrementalCopyBlob',
                'AcquireBlobLease', 'ReleaseBlobLease', 'RenewBlobLease', 'BreakBlobLease',
                'ChangeBlobLease', 'AcquireContainerLease', 'ReleaseContainerLease',
                'RenewContainerLease', 'BreakContainerLease', 'ChangeContainerLease',
                'BlobPreflightRequest', 'SetBlobExpiry', 'SetBlobMetadata',
                'SetBlobProperties', 'SetBlobServiceProperties', 'SetBlobTags',
                'SetContainerACL', 'SetContainerMetadata', 'SnapshotBlob')
        }
        foreach ($category in $blobGroups.Keys) {
            foreach ($api in $blobGroups[$category]) { $blobMap[$api] = $category }
        }
        $lakeMap = @{}
        $lakeGroups = @{
            Reads = @('GetFileProperties', 'GetPathAccessControl', 'GetPathStatus', 'ReadFile')
            Writes = @('CreateFilesystem', 'SetFilesystemProperties', 'CreatePathDir',
                'CreatePathFile', 'AppendFile', 'FlushFile', 'SetFileProperties', 'SetPathAccessControl')
            IterativeReads = @('ListFilesystems', 'ListFilesystemDir', 'ListFilesystemFile')
            IterativeWrites = @('RenamePathDir', 'RenamePathFile', 'SetPathAccessControlRecursive')
            Free = @('DeleteFilesystem', 'DeleteDirectory', 'DeleteFile')
            AllOtherOperations = @('GetFilesystemProperties', 'LeaseFile')
        }
        foreach ($category in $lakeGroups.Keys) {
            foreach ($api in $lakeGroups[$category]) { $lakeMap[$api] = $category }
        }
        $v1Map = $blobMap.Clone()
        foreach ($api in @('GetAccountInformation', 'GetBlobMetadata', 'GetBlobProperties',
            'GetBlobServiceProperties', 'GetBlobServiceStats', 'GetBlobTags', 'GetBlockList',
            'GetContainerACL', 'GetContainerMetadata', 'GetContainerProperties',
            'GetUserDelegationKey', 'AcquireBlobLease', 'ReleaseBlobLease', 'RenewBlobLease',
            'AcquireContainerLease', 'ReleaseContainerLease', 'RenewContainerLease',
            'BlobPreflightRequest', 'SnapshotBlob')) { $v1Map[$api] = 'Reads' }
        foreach ($api in @('AbortCopyBlob', 'IncrementalCopyBlob', 'BreakBlobLease',
            'ChangeBlobLease', 'BreakContainerLease', 'ChangeContainerLease', 'SetBlobExpiry',
            'SetBlobMetadata', 'SetBlobProperties', 'SetBlobServiceProperties', 'SetBlobTags',
            'SetContainerACL', 'SetContainerMetadata')) { $v1Map[$api] = 'Writes' }
        $v1Map['DeleteBlob'] = 'AllOtherOperations'
        $v1Map['DeleteContainer'] = 'AllOtherOperations'
        $v1Map.Remove('QueryBlobContents')

        function Invoke-StorageMetricRequest {
            param([string]$Path, [object]$Context)
            $response = Invoke-AzRestMethod -Path $Path -Method GET -DefaultProfile $Context -ErrorAction Stop
            if ([int]$response.StatusCode -ne 200) {
                throw "ARM HTTP $($response.StatusCode): $($response.Content)"
            }
            $content = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            if ($content -isnot [hashtable]) { throw 'Expected an ARM JSON object response.' }
            return $content
        }

        function Get-TransactionSeries {
            param([hashtable]$Response)
            $metrics = @($Response['value'] | Where-Object { $_['name'] -and $_['name']['value'] -eq 'Transactions' })
            if ($metrics.Count -ne 1) { throw 'Response must contain exactly one Transactions metric.' }
            $metric = $metrics[0]
            if ($metric['errorCode'] -and $metric['errorCode'] -ne 'Success') {
                throw "Transactions error $($metric['errorCode']): $($metric['errorMessage'])"
            }
            if ($metric['unit'] -ne 'Count') { throw 'Transactions metric did not return Count units.' }
            if (-not $metric.ContainsKey('timeseries')) { throw 'Missing Transactions timeseries field.' }
            foreach ($series in $metric['timeseries']) { $series }
        }

        function Get-SeriesCount {
            param([hashtable]$Series)
            $points = @($Series['data'])
            if ($points.Count -gt 1) { throw 'Expected a single FULL interval data point per series.' }
            if ($points.Count -eq 0 -or $null -eq $points[0] -or $null -eq $points[0]['total']) { return $null }
            $number = $points[0]['total']
            if ($number -isnot [ValueType] -or $number -is [bool]) {
                throw 'Transactions Total must be numeric.'
            }
            $count = [decimal]$number
            if ($count -lt 0 -or [decimal]::Truncate($count) -ne $count) {
                throw 'Transactions Total must be a nonnegative integer.'
            }
            return $count
        }

        function New-TransactionRecord {
            param([string]$Type, [string]$Category, [object]$Count,
                [string]$Status, [string]$Completeness, [hashtable]$Dimensions = @{},
                [string]$MappingStatus, [string]$Message)
            $sku = @{}
            $properties = @{}
            if ($account['sku'] -is [hashtable]) { $sku = $account['sku'] }
            if ($account['properties'] -is [hashtable]) { $properties = $account['properties'] }
            [pscustomobject][ordered]@{
                RecordType = $Type
                SubscriptionId = $subscription
                ResourceGroupName = $resourceGroup
                StorageAccountName = $accountName
                ResourceId = $id
                MetricResourceId = "$id/blobServices/default"
                Location = $account['location']
                AccountKind = $account['kind']
                SkuName = $sku['name']
                IsHnsEnabled = $properties['isHnsEnabled']
                AccountDefaultAccessTier = $properties['accessTier']
                StartTime = $chunkStart.ToString('o')
                EndTime = $chunkEnd.ToString('o')
                Category = $Category
                ApiName = $Dimensions['ApiName']
                ResponseType = $Dimensions['ResponseType']
                Tier = $Dimensions['Tier']
                GeoType = $Dimensions['GeoType']
                Authentication = $Dimensions['Authentication']
                TransactionType = $Dimensions['TransactionType']
                RequestCount = $Count
                CountStatus = $Status
                CompletenessStatus = $Completeness
                MappingStatus = $MappingStatus
                QueryAccelerationDataScannedBytes = $null
                QueryAccelerationDataReturnedBytes = $null
                QueryAccelerationStatus = 'UnavailableInPlatformMetrics'
                Message = $Message
            }
        }
    }

    process {
        foreach ($item in $ResourceId) {
            if ($item -notmatch '^/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/([^/?#]+)/providers/Microsoft\.Storage/storageAccounts/([a-z0-9]{3,24})$') {
                throw "Expected a storage account ARM resource ID, not a service ID: $item"
            }
            $parsedSubscription = [guid]::Parse($Matches[1])
            if ($parsedSubscription -eq [guid]::Empty) { throw 'Subscription ID cannot be empty.' }
            [void]$ids.Add($item)
        }
    }

    end {
        foreach ($id in $ids) {
            $parts = $id.Split('/')
            $subscription = $parts[2]
            $resourceGroup = $parts[4]
            $accountName = $parts[8]
            $account = @{ sku = @{}; properties = @{} }
            $chunkStart = $start
            $chunkEnd = $end
            $records = [System.Collections.Generic.List[object]]::new()
            try {
                $matchingContexts = @($contexts | Where-Object { $_.Subscription.Id -eq $subscription })
                if ($matchingContexts.Count -eq 0) {
                    throw "No saved Az context for subscription $subscription. Sign in to that subscription first."
                }
                if ($matchingContexts.Count -gt 1) {
                    throw "Multiple saved Az contexts for subscription $subscription. Retain one unambiguous context before collecting."
                }
                $context = $matchingContexts[0]
                $account = Invoke-StorageMetricRequest -Path "${id}?api-version=2023-05-01" -Context $context
                if (-not $account['kind'] -or $account['sku'] -isnot [hashtable] -or
                    -not $account['sku']['name'] -or $account['properties'] -isnot [hashtable]) {
                    throw 'Account response is missing kind, sku or properties.'
                }
                if ($account.kind -eq 'FileStorage') { throw 'FileStorage accounts are outside Blob/ADLS scope.' }
                $map = $null
                $supportsLake = $false
                if (($account.kind -eq 'StorageV2' -and $account.sku.name -like 'Standard_*') -or
                    ($account.kind -eq 'BlockBlobStorage' -and $account.sku.name -like 'Premium_*')) {
                    $map = $blobMap
                    $supportsLake = $true
                } elseif ($account.kind -eq 'Storage' -and $account.sku.name -like 'Standard_*') {
                    $map = $v1Map
                } else {
                    Write-Warning "$id has no account column in the documented mapping; requests will be Unmapped."
                }
                for ($chunkStart = $start; $chunkStart -lt $end; $chunkStart = $chunkEnd) {
                    $chunkEnd = $chunkStart.AddHours($ChunkHours)
                    if ($chunkEnd -gt $end) { $chunkEnd = $end }
                    $timespan = [uri]::EscapeDataString("$($chunkStart.ToString('o'))/$($chunkEnd.ToString('o'))")
                    $path = "$id/blobServices/default/providers/Microsoft.Insights/metrics" +
                        "?api-version=2023-10-01&metricnamespace=Microsoft.Storage%2FstorageAccounts%2FblobServices" +
                        "&metricnames=Transactions&aggregation=Total&interval=FULL&timespan=$timespan" +
                        '&AutoAdjustTimegrain=false&ValidateDimensions=true'
                    $filter = "ApiName eq '*' and ResponseType eq '*' and Tier eq '*' and " +
                        "GeoType eq '*' and Authentication eq '*' and TransactionType eq '*'"
                    $splitResponse = Invoke-StorageMetricRequest -Path (
                        $path + '&top=10000&%24filter=' + [uri]::EscapeDataString($filter)
                    ) -Context $context
                    $split = @(Get-TransactionSeries -Response $splitResponse)
                    if ($split.Count -ge 10000) {
                        throw 'Split series reached top=10000; completeness cannot be verified. Reduce ChunkHours.'
                    }
                    $totalResponse = Invoke-StorageMetricRequest -Path $path -Context $context
                    $totalSeries = @(Get-TransactionSeries -Response $totalResponse)
                    if ($totalSeries.Count -gt 1) { throw 'Unsplit query unexpectedly returned multiple series.' }
                    $total = $null
                    if ($totalSeries.Count -eq 1) { $total = Get-SeriesCount -Series $totalSeries[0] }
                    $missing = $null -eq $total
                    $splitSum = [decimal]0
                    $details = [System.Collections.Generic.List[object]]::new()
                    $keys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    $sums = @{}
                    foreach ($category in $categories) { $sums[$category] = [decimal]0 }
                    foreach ($series in $split) {
                        $dimensions = @{}
                        foreach ($metadata in $series['metadatavalues']) {
                            $dimensions[$metadata['name']['value']] = $metadata['value']
                        }
                        foreach ($dimension in @('ApiName', 'ResponseType', 'Tier', 'GeoType', 'Authentication', 'TransactionType')) {
                            if (-not $dimensions.ContainsKey($dimension)) {
                                throw "Split series is missing dimension $dimension."
                            }
                        }
                        $key = @($dimensions['ApiName'], $dimensions['ResponseType'], $dimensions['Tier'],
                            $dimensions['GeoType'], $dimensions['Authentication'], $dimensions['TransactionType']) |
                            ConvertTo-Json -Compress
                        if (-not $keys.Add($key)) { throw 'Duplicate split dimension series.' }
                        $count = Get-SeriesCount -Series $series
                        if ($null -eq $count) { $missing = $true } else { $splitSum += $count }
                        $api = $dimensions['ApiName']
                        $category = 'Unmapped'
                        $mappingStatus = 'UnknownApi'
                        if ($null -eq $map) {
                            $mappingStatus = 'UnsupportedAccount'
                        } elseif ($api -eq 'SetBlobTier') {
                            $mappingStatus = 'AmbiguousTierChangeOrBatch'
                        } elseif ($supportsLake -and $lakeMap.ContainsKey($api)) {
                            $category = $lakeMap[$api]
                            $mappingStatus = 'Documented'
                        } elseif ($map.ContainsKey($api)) {
                            $category = $map[$api]
                            $mappingStatus = 'Documented'
                        }
                        if ($category -eq 'Free') { $mappingStatus = 'DocumentedFree' }
                        if ($null -ne $count) { $sums[$category] += $count }
                        $details.Add(@{ Category = $category; Count = $count; Dimensions = $dimensions; MappingStatus = $mappingStatus })
                    }
                    if (-not $missing -and $splitSum -ne $total) {
                        throw "Split count $splitSum does not match unsplit count $total. Possible truncation or changing metrics; retry an older window or reduce ChunkHours."
                    }
                    $completeness = 'Reconciled'
                    $status = 'Observed'
                    if ($missing) {
                        $completeness = 'UnverifiableMissingData'
                        $status = 'MissingData'
                        Write-Warning "$id [$chunkStart, $chunkEnd): missing Totals; category summaries are null."
                    }
                    $records.Add((New-TransactionRecord -Type 'AccountTotal' -Count $total -Status $(
                        if ($null -eq $total) { 'MissingData' } else { 'Observed' }
                    ) -Completeness $completeness))
                    foreach ($category in $categories) {
                        $count = $null
                        if (-not $missing) { $count = $sums[$category] }
                        $records.Add((New-TransactionRecord -Type 'Summary' -Category $category -Count $count `
                            -Status $status -Completeness $completeness))
                    }
                    if ($IncludeDetail) {
                        foreach ($detail in $details) {
                            $records.Add((New-TransactionRecord -Type 'Detail' -Category $detail.Category -Count $detail.Count `
                                -Status $(if ($null -eq $detail.Count) { 'MissingData' } else { 'Observed' }) `
                                -Completeness $completeness -Dimensions $detail.Dimensions -MappingStatus $detail.MappingStatus))
                        }
                    }
                }
                $records
            } catch {
                # Discard this account's buffered chunks rather than returning partial success.
                $message = "Failed collecting ${id}: $($_.Exception.Message)"
                Write-Error -Message $message -ErrorId 'StorageTransactionCollectionFailed' -Category InvalidResult -TargetObject $id
                New-TransactionRecord -Type 'Error' -Status 'Failed' -Completeness 'Failed' -Message $message
            }
        }
    }
}
