function New-EstimateRecord {
    <#
    .SYNOPSIS
    Creates a flat planning record with explicit model assumptions and price time.
    #>
    param(
        [object]$Account, [string]$Scenario, [string]$Type, [string]$Component,
        [switch]$IncludeGeoReplicationTransfer,
        [string]$ModelMonth, [string]$PricingMode, [string]$LegacyTargetTier,
        [datetimeoffset]$PriceTime
    )
    $excludedCharges = @('Retrieval', 'Bandwidth', 'GeoReplicationTransfer',
        'EarlyDeletion', 'Features', 'Migration', 'Discounts', 'Taxes')
    if ($IncludeGeoReplicationTransfer) {
        $excludedCharges = @($excludedCharges | Where-Object { $_ -ne 'GeoReplicationTransfer' })
    }
    [pscustomobject][ordered]@{
        RecordType = $Type; ResourceId = $Account.ResourceId
        StorageAccountName = $Account.StorageAccountName; Location = $Account.Location
        CurrentAccountKind = $Account.AccountKind; CurrentSkuName = $Account.SkuName
        TargetAccountKind = 'StorageV2'; Redundancy = $Scenario; ModelMonth = $ModelMonth
        IsCurrentConfiguration = $null; DeltaFromCurrent = $null; DeltaFromCurrentReason = $null
        Component = $Component; Tier = $null; Quantity = $null; QuantityUnit = $null
        GeoType = $null
        QuantityBasis = $null; SourceStartTime = $null; SourceEndTime = $null
        CapacitySampleTimeUtc = $null; ScaleFactor = $null
        NamespaceBasis = $null
        PricingMode = $PricingMode
        BillabilityAssumption = if ($PricingMode -eq 'AdlsGen2') {
            'Observed requests approximate operations; no 4 MiB read/write expansion or recursive/iterative fan-out inferred.'
        } else { 'Observed requests approximate operations; endpoint schedule explicitly selected, not inferred from HNS.' }
        LegacyTargetTierAssumption = $LegacyTargetTier
        Currency = 'USD'; ProductName = $null; SkuName = $null; MeterName = $null
        MeterId = $null; RateUnit = $null; RateBandsJson = $null; PricesObservedAtUtc = $priceTime.ToString('o')
        EstimatedCost = $null; PricedSubtotal = $null; TotalRecurringCost = $null
        OneTimeCost = $null; Status = $null; Message = $null
        UnpricedComponents = $null
        ExcludedCharges = $excludedCharges -join ';'
    }
}
