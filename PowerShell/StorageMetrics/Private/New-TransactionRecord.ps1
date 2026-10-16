function New-TransactionRecord {
    <#
    .SYNOPSIS
    Creates the flat collector schema from explicit account and window metadata.
    #>
    param([string]$Type, [string]$Category, [object]$Count,
        [string]$Status, [string]$Completeness, [hashtable]$Dimensions = @{},
        [string]$MappingStatus, [string]$Message,
        [hashtable]$Account, [string]$Id, [string]$Subscription,
        [object]$SubscriptionName, [string]$ResourceGroup, [string]$AccountName,
        [object]$ConfigurationObservedAt, [datetimeoffset]$ChunkStart,
        [datetimeoffset]$ChunkEnd, [string]$SummaryPeriod)
    $sku = @{}
    $properties = @{}
    if ($account['sku'] -is [hashtable]) { $sku = $account['sku'] }
    if ($account['properties'] -is [hashtable]) { $properties = $account['properties'] }
    [pscustomobject][ordered]@{
        RecordType = $Type
        SubscriptionId = $subscription
        SubscriptionName = $subscriptionName
        ResourceGroupName = $resourceGroup
        StorageAccountName = $accountName
        ResourceId = $id
        MetricResourceId = "$id/blobServices/default"
        Location = $account['location']
        AccountKind = $account['kind']
        SkuName = $sku['name']
        IsHnsEnabled = $properties['isHnsEnabled']
        AccountDefaultAccessTier = $properties['accessTier']
        PrimaryLocation = $properties['primaryLocation']
        SecondaryLocation = $properties['secondaryLocation']
        IsSftpEnabled = $properties['isSftpEnabled']
        IsNfsV3Enabled = $properties['isNfsV3Enabled']
        ConfigurationObservedAtUtc = $configurationObservedAt
        ConfigurationHistoryStatus = 'CurrentSnapshotOnly'
        StartTime = $chunkStart.ToString('o')
        EndTime = $chunkEnd.ToString('o')
        SummaryPeriod = if ($Type -eq 'Error') { $SummaryPeriod } else { 'Chunk' }
        Month = if ($Type -eq 'Error') { $null } else { $chunkStart.ToString('yyyy-MM', [cultureinfo]::InvariantCulture) }
        IsPartialMonth = $null
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
        QueryWindowHours = if ($SummaryPeriod -eq 'Chunk' -and $Type -ne 'Error') {
            [decimal]($chunkEnd - $chunkStart).TotalHours
        } else { $null }
        Message = $Message
        BilledQuantity = $null
        UnitOfMeasure = $null
        BilledOperationCount = $null
        RequestMinusBilledCount = $null
        ActualCost = $null
        Currency = $null
        MeterId = $null
        MeterName = $null
        MeterSubCategory = $null
        ProductName = $null
        ChargeType = $null
        CostSource = $null
        ComparisonStatus = $null
        MetricName = $null
        BlobType = $null
        AverageUsedBytes = $null
        AverageObservedBytes = $null
        ObservedByteHours = $null
        ExpectedHours = $null
        ObservedHours = $null
        MissingHours = $null
        CapacityStatus = $null
        CapacityReconciliationStatus = $null
        QuantityBasis = $null
        BillingUsageDate = $null
        MeterRegion = $null
        BillingResourceLocation = $null
        MeterCategory = $null
        ConsumedService = $null
        PublisherType = $null
        ProductId = $null
        PricingModel = $null
        ReservationId = $null
        BenefitId = $null
        EffectivePrice = $null
        UnitPrice = $null
        PayGPrice = $null
        PricingCurrency = $null
        ExchangeRatePricingToBilling = $null
        ChargeFrequency = $null
        CostAllocationRuleName = $null
        InvoiceId = $null
        BillingPeriodStartDate = $null
        BillingPeriodEndDate = $null
        ServicePeriodStartDate = $null
        ServicePeriodEndDate = $null
        BillingCoverageStatus = $null
        BillingTier = $null
        BillingRedundancy = $null
        BillingQuantityKind = $null
        NormalizedBilledQuantity = $null
        NormalizedBilledUnit = $null
        BillingMappingStatus = $null
        HasNegativeUsageQuantity = $null
        SourceRecordType = $null
        QuantityKind = $null
        Quantity = $null
        QuantityUnit = $null
        QuantitySource = $null
        QuantityStatus = $null
        ObservedCapacityGiBMonth = $null
        BilledCapacityGiBMonth = $null
        CapacityDifferenceGiBMonth = $null
        CapacityDifferencePercent = $null
        CapacityTierBasis = $null
        CurrentUsedBytes = $null
        CurrentUsedGiB = $null
        CapacitySampleTimeUtc = $null
        CapacitySampleAgeHours = $null
    }
}
