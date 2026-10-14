#Requires -Version 7.0

function Get-StorageTransactionCostComparison {
    <#
    .SYNOPSIS
    Builds billed-usage comparisons for the transaction collector.
    .DESCRIPTION
    Companion implementation loaded by Get-AzStorageTransactionMetric only when
    cost comparison is requested. Use that public function, not this helper.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Records,
        [Parameter(Mandatory)][object[]]$Contexts,
        [string[]]$CsvPaths,
        [switch]$IncludeDetail
    )

    function Get-CostField {
        param([object]$Row, [string[]]$Names, [switch]$Required)
        foreach ($name in $Names) {
            $property = $Row.PSObject.Properties[$name]
            if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                return [string]$property.Value
            }
        }
        if ($Required) { throw "Cost details field missing: $($Names -join '/')." }
        return $null
    }

    function Get-CostDecimal {
        param([string]$Value, [string]$Name)
        $number = [decimal]0
        if (-not [decimal]::TryParse($Value, [Globalization.NumberStyles]::Float,
                [cultureinfo]::InvariantCulture, [ref]$number)) {
            throw "Invalid cost details number in $Name."
        }
        return $number
    }

    function Import-CostRows {
        param([string[]]$Paths)
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($path in $Paths) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Cost CSV not found: $path" }
            $resolved = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
            if (-not $seen.Add($resolved)) { throw "Duplicate cost CSV: $path" }
            Import-Csv -LiteralPath $path -ErrorAction Stop
        }
    }

    function Get-ReportHeader {
        param([object]$Response, [string]$Name)
        foreach ($header in $Response.Headers) {
            if ($header.Key -eq $Name) { return @($header.Value)[0] }
        }
        return $null
    }

    function Get-LiveCostRows {
        param([object]$Template, [object]$Context)
        $subscription = $Template.SubscriptionId
        $armUri = [uri]$Context.Environment.ResourceManagerUrl
        $payload = @{
            metric = 'ActualCost'
            timePeriod = @{
                start = ([datetimeoffset]$Template.StartTime).ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
                end = ([datetimeoffset]$Template.EndTime).AddDays(-1).ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
            }
        } | ConvertTo-Json -Depth 4
        $response = Invoke-AzRestMethod -Path (
            "/subscriptions/$subscription/providers/Microsoft.CostManagement/generateCostDetailsReport?api-version=2022-05-01"
        ) -Method POST -Payload $payload -DefaultProfile $Context -ErrorAction Stop
        $deadline = [datetimeoffset]::UtcNow.AddMinutes(10)
        $pollCount = 0
        while ([int]$response.StatusCode -eq 202) {
            $pollCount++
            $location = Get-ReportHeader $response 'Location'
            if (-not $location -and $pollCount -gt 1) { $location = $pollUri.AbsoluteUri }
            $pollUri = $null
            if (-not [uri]::TryCreate($location, [UriKind]::Absolute, [ref]$pollUri) -or
                $pollUri.Scheme -ne 'https' -or $pollUri.Authority -ne $armUri.Authority -or
                -not $pollUri.AbsolutePath.StartsWith("/subscriptions/$subscription/", [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Cost Details returned an invalid polling location.'
            }
            $retryText = Get-ReportHeader $response 'Retry-After'
            $seconds = 0
            if (-not [int]::TryParse($retryText, [ref]$seconds) -or $seconds -lt 0) {
                throw 'Cost Details returned an invalid Retry-After header.'
            }
            if ($pollCount -gt 30 -or [datetimeoffset]::UtcNow.AddSeconds($seconds) -gt $deadline) {
                throw 'Cost Details report did not complete within the polling limit; retry later.'
            }
            Start-Sleep -Seconds $seconds
            $response = Invoke-AzRestMethod -Uri $pollUri.AbsoluteUri -Method GET -DefaultProfile $Context -ErrorAction Stop
        }
        if ([int]$response.StatusCode -ne 200) {
            throw "Cost Details report HTTP $($response.StatusCode). Verify cost permissions and billing-offer support; use CostDetailsCsv for unsupported offers."
        }
        try { $body = $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
        catch { throw 'Cost Details returned an invalid JSON report manifest.' }
        $manifest = $body['manifest']
        if ($manifest -isnot [hashtable] -or $manifest['dataFormat'] -ne 'Csv' -or
            $manifest['compressData'] -ne $false -or -not $manifest.ContainsKey('blobs') -or
            $manifest['blobCount'] -ne @($manifest['blobs']).Count) {
            throw 'Expected an uncompressed CSV manifest with every report partition.'
        }
        $downloaded = [System.Collections.Generic.List[object]]::new()
        $seenLinks = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($blob in $manifest['blobs']) {
            $downloadUri = $null
            $suffix = ".blob.$($Context.Environment.StorageEndpointSuffix)"
            if (-not [uri]::TryCreate($blob['blobLink'], [UriKind]::Absolute, [ref]$downloadUri) -or
                $downloadUri.Scheme -ne 'https' -or -not $downloadUri.IsDefaultPort -or
                -not $downloadUri.Host.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Cost Details returned an invalid report download location.'
            }
            if (-not $seenLinks.Add($downloadUri.AbsoluteUri)) { throw 'Cost Details returned duplicate report partitions.' }
            $file = [IO.Path]::GetTempFileName()
            try {
                try {
                    Invoke-WebRequest -Uri $downloadUri.AbsoluteUri -OutFile $file -MaximumRedirection 0 -ErrorAction Stop | Out-Null
                } catch {
                    # HTTP exception messages can contain the signed report URL.
                    throw 'Cost Details CSV download failed; retry report generation.'
                }
                foreach ($row in (Import-CostRows -Paths @($file))) { $downloaded.Add($row) }
            } finally {
                Remove-Item -LiteralPath $file -ErrorAction Stop
            }
        }
        return $downloaded.ToArray()
    }

    function New-CostMeter {
        param([object]$Row, [object]$Template, [datetimeoffset]$UsageDate)
        $record = $Template.PSObject.Copy()
        $record.RecordType = 'CostMeter'
        $record.Category = $null
        $record.RequestCount = $null
        $record.CountStatus = $null
        $record.MeterId = Get-CostField $Row @('MeterId') -Required
        $record.MeterName = Get-CostField $Row @('MeterName') -Required
        $record.MeterSubCategory = Get-CostField $Row @('MeterSubCategory') -Required
        $record.ProductName = Get-CostField $Row @('ProductName', 'Product')
        $record.UnitOfMeasure = Get-CostField $Row @('UnitOfMeasure') -Required
        $record.Currency = Get-CostField $Row @('BillingCurrency', 'BillingCurrencyCode', 'Currency') -Required
        $record.ChargeType = Get-CostField $Row @('ChargeType') -Required
        $record.BilledQuantity = Get-CostDecimal (Get-CostField $Row @('Quantity', 'UsageQuantity') -Required) 'Quantity'
        $record.ActualCost = Get-CostDecimal (Get-CostField $Row @('CostInBillingCurrency', 'Cost', 'PreTaxCost') -Required) 'ActualCost'
        $record.BillingUsageDate = $UsageDate.ToUniversalTime().ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)
        foreach ($field in $contextFields.Keys) {
            $text = Get-CostField $Row $contextFields[$field]
            $record.$field = $text
            if ($field -in $numericContextFields -and $null -ne $text) {
                $record.$field = Get-CostDecimal $text $field
            }
        }
        $record.BillingCoverageStatus = $billingCoverage
        $record.CompletenessStatus = $billingCoverage
        $record.QuantityBasis = 'BillingReportedUsage'
        $record.BillingMappingStatus = 'Unclassified'
        $record.ComparisonStatus = 'NotOperationMeter'
        $record.CostSource = $costSource
        # Catalog context excludes Defender, Files, Queue and Table meters.
        $blobCatalog = $record.MeterSubCategory -in @('Blob Storage', 'General Block Blob', 'General Block Blob v2', 'Azure Data Lake Storage Gen2')
        $name = $record.MeterName
        if ($blobCatalog -or $record.MeterSubCategory -eq 'Blob Features') {
            if ($name -match '^(Hot|Cool|Cold|Archive) (.+)$') {
                $record.BillingTier = $Matches[1]
                $name = $Matches[2]
            }
            if ($name -match '^(LRS|ZRS|GRS|RA-GRS|GZRS|RA-GZRS) (.+)$') {
                $record.BillingRedundancy = $Matches[1]
                $name = $Matches[2]
            }
        }
        if ($blobCatalog) {
            $meterCategories = @{
                'Read Operations' = 'Reads'
                'Write Operations' = 'Writes'
                'Iterative Read Operations' = 'IterativeReads'
                'Iterative Write Operations' = 'IterativeWrites'
                'All Other Operations' = 'AllOtherOperations'
                'List and Create Container Operations' = 'ListAndCreateContainer'
            }
            if ($meterCategories.ContainsKey($name)) {
                $record.Category = $meterCategories[$name]
                $record.ComparisonStatus = 'VerifiedOperationUnit'
                $multiplier = switch ($record.UnitOfMeasure) {
                    '10K' { [decimal]10000 }
                    '10,000 Operations' { [decimal]10000 }
                    '1 Operations' { [decimal]1 }
                    '100' { [decimal]100 }
                    '100 Operations' { [decimal]100 }
                    default { $null }
                }
                if ($null -eq $multiplier) {
                    $record.ComparisonStatus = 'UnverifiedUnit'
                } else {
                    $record.BilledOperationCount = $record.BilledQuantity * $multiplier
                    $record.NormalizedBilledQuantity = $record.BilledOperationCount
                    $record.NormalizedBilledUnit = 'Operations'
                }
                $record.BillingQuantityKind = 'Operations'
                $record.BillingMappingStatus = $record.ComparisonStatus
            } elseif ($record.MeterName -match 'Operation|Transaction') {
                $record.ComparisonStatus = 'UnmappedOperationMeter'
                $record.BillingMappingStatus = 'UnmappedOperationMeter'
            }
        }
        if (-not $record.BillingQuantityKind) {
            # Exact names are catalog-backed; a GB label is not assumed to mean bytes.
            $quantityKinds = @{
                'Data Stored' = 'Capacity'; 'Index' = 'HnsIndexCapacity'
                'Data Retrieval' = 'Retrieval'; 'Priority Data Retrieval' = 'Retrieval'
                'Early Delete' = 'EarlyDeletion'
                'Data Scanned for Query Acceleration' = 'QueryAccelerationScanned'
                'Data Returned for Query Acceleration' = 'QueryAccelerationReturned'
                'Blob Inventory' = 'InventoryObjects'; 'Index Tags' = 'IndexTags'
                'Named Encryption Scopes' = 'EncryptionScopes'
            }
            if (($blobCatalog -or $record.MeterSubCategory -eq 'Blob Features') -and $quantityKinds.ContainsKey($name)) {
                $record.BillingQuantityKind = $quantityKinds[$name]
            } elseif ($record.MeterSubCategory -eq 'Blob Features' -and
                $record.MeterName -match '^SSH File Transfer Protocol (LRS|ZRS|GRS|RA-GRS|GZRS|RA-GZRS) Hour Enabled$') {
                $record.BillingQuantityKind = 'SftpEnabledHours'
                $record.BillingRedundancy = $Matches[1]
            } elseif ($record.MeterSubCategory -eq 'Blob Features' -and
                $record.MeterName -match '^Point-in-time Restore (LRS|GRS) Data Processed$') {
                $record.BillingQuantityKind = 'RestoreDataProcessed'
                $record.BillingRedundancy = $Matches[1]
            } elseif ($record.MeterCategory -eq 'Bandwidth' -and
                $record.MeterName -in @('Intra Continent Data Transfer Out', 'Inter Continent Data Transfer Out', 'Standard Data Transfer Out')) {
                $record.BillingQuantityKind = 'NetworkTransfer'
            } elseif (($record.ProductName -eq 'Storage - Bandwidth' -or
                    $record.MeterSubCategory -in @('Geo-Replication', 'Geo-Replication v2')) -and
                $record.MeterName -in @('Geo-Replication Data Transfer', 'Geo-Replication v2 Data Transfer')) {
                $record.BillingQuantityKind = 'GeoReplicationTransfer'
            }
            if ($record.BillingQuantityKind) {
                $unit = $null
                $multiplier = [decimal]1
                switch ($record.BillingQuantityKind) {
                    { $_ -in @('Capacity', 'HnsIndexCapacity') } {
                        if ($record.UnitOfMeasure -in @('1 GB/Month', 'GB/Month')) { $unit = 'GiBMonth' }
                    }
                    { $_ -in @('Retrieval', 'EarlyDeletion', 'GeoReplicationTransfer', 'QueryAccelerationScanned', 'QueryAccelerationReturned', 'NetworkTransfer') } {
                        if ($record.UnitOfMeasure -in @('1 GB', 'GB')) { $unit = 'BillingGB' }
                    }
                    'SftpEnabledHours' { if ($record.UnitOfMeasure -in @('1', '1 Hour')) { $unit = 'Hours' } }
                    'InventoryObjects' { if ($record.UnitOfMeasure -eq '1M') { $unit = 'Objects'; $multiplier = 1000000 } }
                    'IndexTags' { if ($record.UnitOfMeasure -eq '10K/Month') { $unit = 'TagMonths'; $multiplier = 10000 } }
                    'EncryptionScopes' { if ($record.UnitOfMeasure -eq '1/Month') { $unit = 'ScopeMonths' } }
                    'RestoreDataProcessed' { if ($record.UnitOfMeasure -eq '1 MB') { $unit = 'BillingMB' } }
                }
                $record.BillingMappingStatus = if ($unit) { 'VerifiedMeterUnit' } else { 'UnverifiedUnit' }
                if ($unit) {
                    $record.NormalizedBilledUnit = $unit
                    $record.NormalizedBilledQuantity = $record.BilledQuantity * $multiplier
                }
            }
        }
        if ($record.ChargeType -ne 'Usage') {
            $record.ComparisonStatus = 'NonUsageCharge'
            $record.BilledOperationCount = $null
            $record.NormalizedBilledQuantity = $null
            $record.NormalizedBilledUnit = $null
            $record.BillingMappingStatus = 'NonUsageCharge'
        }
        return $record
    }

    $costSource = if ($CsvPaths) { 'Csv' } else { 'CostDetailsApi' }
    $billingCoverage = if ($CsvPaths) { 'CsvCoverageUnverified' } else { 'ReportPartitionsRead' }
    $numericContextFields = @('EffectivePrice', 'UnitPrice', 'PayGPrice', 'ExchangeRatePricingToBilling')
    $contextFields = @{
        MeterRegion = @('MeterRegion'); BillingResourceLocation = @('ResourceLocation', 'Location')
        MeterCategory = @('MeterCategory'); ConsumedService = @('ConsumedService')
        PublisherType = @('PublisherType'); ProductId = @('ProductId')
        PricingModel = @('PricingModel'); ReservationId = @('ReservationId'); BenefitId = @('BenefitId')
        EffectivePrice = @('EffectivePrice', 'ResourceRate'); UnitPrice = @('UnitPrice')
        PayGPrice = @('PayGPrice', 'pay-as-you-goPrice'); PricingCurrency = @('PricingCurrency')
        ExchangeRatePricingToBilling = @('ExchangeRatePricingToBilling'); ChargeFrequency = @('Frequency')
        CostAllocationRuleName = @('CostAllocationRuleName'); InvoiceId = @('InvoiceId')
        BillingPeriodStartDate = @('BillingPeriodStartDate'); BillingPeriodEndDate = @('BillingPeriodEndDate')
        ServicePeriodStartDate = @('ServicePeriodStartDate'); ServicePeriodEndDate = @('ServicePeriodEndDate')
    }
    $csvRows = @()
    $csvFailure = $null
    if ($CsvPaths) {
        try { $csvRows = @(Import-CostRows -Paths $CsvPaths) }
        catch { $csvFailure = $_.Exception.Message }
    }
    $totals = @($Records | Where-Object RecordType -eq 'AccountTotal')
    foreach ($period in ($totals | Group-Object SubscriptionId, Month)) {
        $templates = $period.Group
        try {
            if ($csvFailure) { throw $csvFailure }
            $sourceRows = $csvRows
            if (-not $CsvPaths) {
                $matchingContexts = @($Contexts | Where-Object { $_.Subscription.Id -eq $templates[0].SubscriptionId })
                if ($matchingContexts.Count -ne 1) { throw 'Cost comparison requires one saved context for its subscription.' }
                $sourceRows = @(Get-LiveCostRows -Template $templates[0] -Context $matchingContexts[0])
            }
            $meters = [System.Collections.Generic.List[object]]::new()
            $unassignedCount = 0
            foreach ($row in $sourceRows) {
                if ($null -eq $row.PSObject.Properties['ResourceId'] -and
                    $null -eq $row.PSObject.Properties['InstanceId']) {
                    throw 'Cost CSV requires ResourceId or InstanceId columns.'
                }
                $resource = Get-CostField $row @('ResourceId', 'InstanceId')
                if (-not $resource) { $unassignedCount++; continue }
                $template = @($templates | Where-Object ResourceId -eq $resource)
                if (-not $template.Count) { continue }
                $dateText = Get-CostField $row @('Date', 'UsageDate', 'UsageStart', 'UsageDateTime') -Required
                $date = [datetimeoffset]::MinValue
                [string[]]$formats = @('yyyy-MM-dd', 'MM/dd/yyyy', 'M/d/yyyy', 'yyyy-MM-ddTHH:mm:ssZ',
                    'yyyy-MM-ddTHH:mm:sszzz', 'o')
                if (-not [datetimeoffset]::TryParseExact($dateText, $formats,
                        [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$date)) {
                    throw 'Invalid or unsupported cost details usage date.'
                }
                if ($date -lt [datetimeoffset]$template[0].StartTime -or $date -ge [datetimeoffset]$template[0].EndTime) { continue }
                $meters.Add((New-CostMeter -Row $row -Template $template[0] -UsageDate $date))
            }
            if ($unassignedCount) {
                Write-Warning "$unassignedCount unassigned cost rows cannot be attributed to selected accounts and were excluded."
            }
            $output = [System.Collections.Generic.List[object]]::new()
            $meterGroups = $meters | Group-Object -CaseSensitive -Property {
                $groupKey = @($_.ResourceId.ToLowerInvariant(), $_.MeterId,
                    $_.MeterName, $_.MeterSubCategory, $_.ProductName, $_.UnitOfMeasure,
                    $_.Currency, $_.ChargeType)
                foreach ($field in ($contextFields.Keys | Sort-Object)) { $groupKey += $_.$field }
                ConvertTo-Json -InputObject $groupKey -Compress
            }
            foreach ($group in $meterGroups) {
                $record = $group.Group[0].PSObject.Copy()
                $record.BilledQuantity = [decimal]0
                $record.ActualCost = [decimal]0
                $record.BillingUsageDate = $null
                $count = [decimal]0
                $normalized = [decimal]0
                foreach ($meter in $group.Group) {
                    $record.BilledQuantity += $meter.BilledQuantity
                    $record.ActualCost += $meter.ActualCost
                    if ($null -ne $meter.BilledOperationCount) { $count += $meter.BilledOperationCount }
                    if ($null -ne $meter.NormalizedBilledQuantity) { $normalized += $meter.NormalizedBilledQuantity }
                }
                if ($null -ne $record.BilledOperationCount) { $record.BilledOperationCount = $count }
                if ($null -ne $record.NormalizedBilledQuantity) { $record.NormalizedBilledQuantity = $normalized }
                $output.Add($record)
            }
            if ($IncludeDetail) {
                foreach ($meter in $meters) {
                    $detail = $meter.PSObject.Copy()
                    $detail.RecordType = 'CostDetail'
                    $output.Add($detail)
                }
            }
            foreach ($template in $templates) {
                $summaries = @($Records | Where-Object {
                    $_.ResourceId -eq $template.ResourceId -and $_.Month -eq $template.Month -and $_.RecordType -eq 'Summary'
                })
                foreach ($summary in $summaries) {
                    $matched = @($output | Where-Object {
                        $_.RecordType -eq 'CostMeter' -and $_.ResourceId -eq $summary.ResourceId -and
                        $_.Category -eq $summary.Category -and $_.ChargeType -eq 'Usage'
                    })
                    $currencyGroups = @($matched | Group-Object Currency)
                    if (-not $currencyGroups.Count) { $currencyGroups = @([pscustomobject]@{Group=@();Name=$null}) }
                    foreach ($currencyGroup in $currencyGroups) {
                        $comparison = $summary.PSObject.Copy()
                        $comparison.RecordType = 'CostComparison'
                        $comparison.CostSource = $costSource
                        $comparison.BillingCoverageStatus = $billingCoverage
                        $comparison.Currency = $currencyGroup.Name
                        $comparison.ComparisonStatus = 'NoMatchingBillingMeter'
                        if ($currencyGroup.Group.Count) {
                            $billed = [decimal]0
                            $cost = [decimal]0
                            $unknown = $false
                            foreach ($meter in $currencyGroup.Group) {
                                $cost += $meter.ActualCost
                                if ($null -eq $meter.BilledOperationCount) { $unknown = $true }
                                else { $billed += $meter.BilledOperationCount }
                            }
                            $comparison.ActualCost = $cost
                            if ($unknown) {
                                $comparison.ComparisonStatus = 'UnverifiedUnit'
                            } else {
                                $comparison.BilledOperationCount = $billed
                                if ($summary.CompletenessStatus -ne 'Reconciled' -or $null -eq $summary.RequestCount) {
                                    $comparison.ComparisonStatus = 'MetricsIncomplete'
                                } else {
                                    $comparison.RequestMinusBilledCount = $summary.RequestCount - $billed
                                    $comparison.ComparisonStatus = if ($summary.RequestCount -eq $billed) { 'CountsMatch' } else { 'CountsDiffer' }
                                }
                            }
                        }
                        $output.Add($comparison)
                    }
                }
            }
            $output
        } catch {
            $message = "Cost comparison failed for subscription/month $($period.Name): $($_.Exception.Message)"
            Write-Error -Message $message -ErrorId 'StorageCostComparisonFailed' -Category InvalidResult
            foreach ($template in $templates) {
                $record = $template.PSObject.Copy()
                $record.RecordType = 'CostError'
                $record.RequestCount = $null
                $record.CountStatus = $null
                $record.CompletenessStatus = 'Failed'
                $record.ComparisonStatus = 'Failed'
                $record.CostSource = $costSource
                $record.Message = $message
                $record
            }
        }
    }
}
