function Set-RetailCost {
    <#
    .SYNOPSIS
    Prices one line using exact catalog identity and graduated decimal rate bands.
    #>
    param([object]$Line, [object[]]$Catalog, [string[]]$MeterNames, [string]$Unit, [datetimeoffset]$PriceTime)
    $Line.RateUnit = $Unit
    $catalogMatches = @($Catalog | Where-Object {
        $_.serviceName -eq 'Storage' -and $_.armRegionName -eq $Line.Location -and
        $_.productName -eq $Line.ProductName -and $_.skuName -eq $Line.SkuName -and
        $_.meterName -in $MeterNames -and $_.unitOfMeasure -eq $Unit -and
        $_.currencyCode -eq 'USD' -and $_.type -eq 'Consumption' -and
        [datetimeoffset]$_.effectiveStartDate -le $priceTime
    })
    if (-not $catalogMatches.Count) { $Line.Status = 'PriceUnavailable'; return }
    if (@($catalogMatches | Group-Object meterId, meterName).Count -ne 1) {
        $Line.Status = 'AmbiguousPrice'; return
    }
    $bands = @(
        foreach ($group in ($catalogMatches | Group-Object tierMinimumUnits)) {
            $latest = @($group.Group | Sort-Object { [datetimeoffset]$_.effectiveStartDate } -Descending)
            $sameDate = @($latest | Where-Object effectiveStartDate -eq $latest[0].effectiveStartDate)
            if ($sameDate.Count -ne 1) { $Line.Status = 'AmbiguousPrice'; return }
            $latest[0]
        }
    ) | Sort-Object { [decimal]$_.tierMinimumUnits }
    if (-not $bands.Count -or [decimal]$bands[0].tierMinimumUnits -ne 0) {
        $Line.Status = 'PriceUnavailable'; return
    }
    $cost = [decimal]0
    for ($i = 0; $i -lt $bands.Count; $i++) {
        $band = $bands[$i]
        if ($null -eq $band.retailPrice -or [decimal]$band.retailPrice -lt 0 -or
            [decimal]$band.tierMinimumUnits -lt 0) { throw 'Retail catalog contains an invalid rate band.' }
        $quantity = $Line.Quantity
        if ($Unit -eq '10K') { $quantity /= [decimal]10000 }
        elseif ($Unit -eq '100') { $quantity /= [decimal]100 }
        $upper = if ($i + 1 -lt $bands.Count) { [decimal]$bands[$i + 1].tierMinimumUnits } else { $quantity }
        $used = [math]::Max([decimal]0, [math]::Min($quantity, $upper) - [decimal]$band.tierMinimumUnits)
        $cost += $used * [decimal]$band.retailPrice
    }
    $Line.EstimatedCost = $cost
    $Line.MeterName = $bands[0].meterName
    $Line.MeterId = $bands[0].meterId
    $Line.RateBandsJson = ConvertTo-Json -InputObject @($bands | Select-Object tierMinimumUnits, retailPrice, effectiveStartDate, isPrimaryMeterRegion) -Compress
    $Line.Status = 'PlanningEstimate'
}
