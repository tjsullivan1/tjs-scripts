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
        [switch]$IncludeDetail,
        [ValidateRange(1, 60)][int]$CostReportTimeoutMinutes = 10,
        [hashtable]$Policy
    )

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
    $summariesByResourceMonth = @{}
    foreach ($summary in ($Records | Where-Object RecordType -eq 'Summary')) {
        $key = Get-CostLookupKey -ResourceId $summary.ResourceId -Part1 $summary.Month -Part2 'Summary'
        if (-not $summariesByResourceMonth.ContainsKey($key)) {
            $summariesByResourceMonth[$key] = [System.Collections.Generic.List[object]]::new()
        }
        $summariesByResourceMonth[$key].Add($summary)
    }
    foreach ($period in ($totals | Group-Object SubscriptionId, Month)) {
        $templates = $period.Group
        $templatesByResourceId = @{}
        foreach ($template in $templates) {
            $key = ([string]$template.ResourceId).ToLowerInvariant()
            if (-not $templatesByResourceId.ContainsKey($key)) { $templatesByResourceId[$key] = $template }
        }
        try {
            if ($csvFailure) { throw $csvFailure }
            $sourceRows = $csvRows
            if (-not $CsvPaths) {
                $matchingContexts = @($Contexts | Where-Object { $_.Subscription.Id -eq $templates[0].SubscriptionId })
                if ($matchingContexts.Count -ne 1) { throw 'Cost comparison requires one saved context for its subscription.' }
                $sourceRows = @(Get-LiveCostRows -Template $templates[0] -Context $matchingContexts[0] `
                    -TimeoutMinutes $CostReportTimeoutMinutes)
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
                $templateKey = $resource.ToLowerInvariant()
                if (-not $templatesByResourceId.ContainsKey($templateKey)) { continue }
                $template = $templatesByResourceId[$templateKey]
                $dateText = Get-CostField $row @('Date', 'UsageDate', 'UsageStart', 'UsageDateTime') -Required
                $date = [datetimeoffset]::MinValue
                [string[]]$formats = @('yyyy-MM-dd', 'MM/dd/yyyy', 'M/d/yyyy', 'yyyy-MM-ddTHH:mm:ssZ',
                    'yyyy-MM-ddTHH:mm:sszzz', 'o')
                if (-not [datetimeoffset]::TryParseExact($dateText, $formats,
                        [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$date)) {
                    throw 'Invalid or unsupported cost details usage date.'
                }
                if ($date -lt [datetimeoffset]$template.StartTime -or $date -ge [datetimeoffset]$template.EndTime) { continue }
                $meters.Add((New-CostMeter -Row $row -Template $template -UsageDate $date `
                    -ContextFields $contextFields -NumericContextFields $numericContextFields `
                    -BillingCoverage $billingCoverage -CostSource $costSource -Policy $Policy))
            }
            if ($unassignedCount) {
                Write-Warning "$unassignedCount unassigned cost rows cannot be attributed to selected accounts and were excluded."
            }
            $output = [System.Collections.Generic.List[object]]::new()
            $costMetersByResourceCategory = @{}
            $meterGroups = $meters | Group-Object -CaseSensitive -Property {
                $groupKey = @($_.ResourceId.ToLowerInvariant(), $_.MeterId,
                    $_.MeterName, $_.MeterSubCategory, $_.ProductName, $_.UnitOfMeasure,
                    $_.Currency, $_.ChargeType)
                foreach ($field in ($contextFields.Keys | Sort-Object)) { $groupKey += $_.$field }
                ConvertTo-Json -InputObject $groupKey -Compress
            }
            foreach ($group in $meterGroups) {
                $record = ConvertTo-CostMeterRecord -Data $group.Group[0]
                $record.BilledQuantity = [decimal]0
                $record.ActualCost = [decimal]0
                $record.HasNegativeUsageQuantity = $false
                $record.BillingUsageDate = $null
                $count = [decimal]0
                $normalized = [decimal]0
                foreach ($meter in $group.Group) {
                    $record.BilledQuantity += $meter.BilledQuantity
                    $record.ActualCost += $meter.ActualCost
                    if ($meter.HasNegativeUsageQuantity) { $record.HasNegativeUsageQuantity = $true }
                    if ($null -ne $meter.BilledOperationCount) { $count += $meter.BilledOperationCount }
                    if ($null -ne $meter.NormalizedBilledQuantity) { $normalized += $meter.NormalizedBilledQuantity }
                }
                if ($null -ne $record.BilledOperationCount) { $record.BilledOperationCount = $count }
                if ($null -ne $record.NormalizedBilledQuantity) { $record.NormalizedBilledQuantity = $normalized }
                $output.Add($record)
                $key = Get-CostLookupKey -ResourceId $record.ResourceId -Part1 $record.Category -Part2 $record.ChargeType
                if (-not $costMetersByResourceCategory.ContainsKey($key)) {
                    $costMetersByResourceCategory[$key] = [System.Collections.Generic.List[object]]::new()
                }
                $costMetersByResourceCategory[$key].Add($record)
            }
            if ($IncludeDetail) {
                foreach ($meter in $meters) {
                    $detail = ConvertTo-CostMeterRecord -Data $meter
                    $detail.RecordType = 'CostDetail'
                    $output.Add($detail)
                }
            }
            foreach ($template in $templates) {
                $summaryKey = Get-CostLookupKey -ResourceId $template.ResourceId -Part1 $template.Month -Part2 'Summary'
                $summaries = if ($summariesByResourceMonth.ContainsKey($summaryKey)) {
                    $summariesByResourceMonth[$summaryKey]
                } else { @() }
                foreach ($summary in $summaries) {
                    $matchedKey = Get-CostLookupKey -ResourceId $summary.ResourceId -Part1 $summary.Category -Part2 'Usage'
                    $matched = if ($costMetersByResourceCategory.ContainsKey($matchedKey)) {
                        $costMetersByResourceCategory[$matchedKey]
                    } else { @() }
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
            $output.ToArray()
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
