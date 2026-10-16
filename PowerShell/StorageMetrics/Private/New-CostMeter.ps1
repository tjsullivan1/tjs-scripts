function New-CostMeter {
    <#
    .SYNOPSIS
    Classifies a billing row using explicit policy and report context.
    #>
    param([object]$Row, [object]$Template, [datetimeoffset]$UsageDate,
        [hashtable]$ContextFields, [string[]]$NumericContextFields,
        [string]$BillingCoverage, [string]$CostSource, [hashtable]$Policy)
    $record = @{
        Template = $Template
        ResourceId = $Template.ResourceId
        Category = $null
        BillingTier = $null
        BillingRedundancy = $null
        BillingQuantityKind = $null
        BilledOperationCount = $null
        NormalizedBilledQuantity = $null
        NormalizedBilledUnit = $null
    }
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
    $record.HasNegativeUsageQuantity = $record.ChargeType -eq 'Usage' -and $record.BilledQuantity -lt 0
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
        $meterCategories = $Policy.MeterCategories.Values
        if ($meterCategories.ContainsKey($name)) {
            $record.Category = $meterCategories[$name]
            $record.ComparisonStatus = 'VerifiedOperationUnit'
            $multiplier = $null
            if ($Policy.OperationUnitMultipliers.Values.ContainsKey($record.UnitOfMeasure)) {
                $multiplier = [decimal]$Policy.OperationUnitMultipliers.Values[$record.UnitOfMeasure]
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
        $quantityKinds = $Policy.QuantityKinds.Values
        if (($blobCatalog -or $record.MeterSubCategory -eq 'Blob Features') -and $quantityKinds.ContainsKey($name)) {
            $record.BillingQuantityKind = $quantityKinds[$name]
        } elseif ($record.MeterSubCategory -eq 'Blob Features' -and
            $record.MeterName -match $Policy.QuantityKinds.SftpMeterPattern) {
            $record.BillingQuantityKind = 'SftpEnabledHours'
            $record.BillingRedundancy = $Matches[1]
        } elseif ($record.MeterSubCategory -eq 'Blob Features' -and
            $record.MeterName -match $Policy.QuantityKinds.RestoreMeterPattern) {
            $record.BillingQuantityKind = 'RestoreDataProcessed'
            $record.BillingRedundancy = $Matches[1]
        } elseif ($record.MeterCategory -eq 'Bandwidth' -and
            $record.MeterName -in $Policy.QuantityKinds.NetworkMeters) {
            $record.BillingQuantityKind = 'NetworkTransfer'
        } elseif (($record.ProductName -eq $Policy.RetailProducts.GeoReplication -or
                $record.MeterSubCategory -in @('Geo-Replication', 'Geo-Replication v2')) -and
            $record.MeterName -in $Policy.QuantityKinds.GeoReplicationMeters) {
            $record.BillingQuantityKind = 'GeoReplicationTransfer'
        }
        if ($record.BillingQuantityKind) {
            $unit = $null
            $multiplier = [decimal]1
            $quantityPolicy = $Policy.QuantityUnits.Values[$record.BillingQuantityKind]
            if ($null -ne $quantityPolicy -and $record.UnitOfMeasure -in $quantityPolicy.Units) {
                $unit = $quantityPolicy.Unit
                $multiplier = [decimal]$quantityPolicy.Multiplier
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
