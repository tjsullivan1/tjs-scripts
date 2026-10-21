function Get-RetailCatalog {
    <#
    .SYNOPSIS
    Retrieves the selected policy products from validated public retail catalog pages.
    #>
    param([string]$Region, [string]$PricingMode, [bool]$GeoReplicationCatalogNeeded, [hashtable]$Policy)
    if ($Region -notmatch '^[a-z0-9]+$') { throw "Invalid Azure region: $Region" }
    $productNames = @($Policy.RetailProducts.Values[$PricingMode].Catalog)
    if ($GeoReplicationCatalogNeeded) { $productNames += $Policy.RetailProducts.GeoReplication }
    $products = (@($productNames | ForEach-Object { "productName eq '$($_.Replace("'", "''"))'" }) -join ' or ')
    if ($productNames.Count -gt 1) { $products = "($products)" }
    $filter = "serviceName eq 'Storage' and armRegionName eq '$Region' and priceType eq 'Consumption' and $products"
    $uri = 'https://prices.azure.com/api/retail/prices?api-version=2023-01-01-preview&%24filter=' +
        [uri]::EscapeDataString($filter)
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $items = [System.Collections.Generic.List[object]]::new()
    while ($uri) {
        $link = [uri]$uri
        if ($link.Scheme -ne 'https' -or $link.Host -ne 'prices.azure.com' -or
            $link.AbsolutePath -ne '/api/retail/prices' -or -not $link.IsDefaultPort -or $link.UserInfo) {
            throw 'Retail catalog returned an unexpected pagination URL.'
        }
        if (-not $seen.Add($uri) -or $seen.Count -gt 100) { throw 'Retail pagination is cyclic or exceeds 100 pages.' }
        $page = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        if ($null -eq $page.Items) { throw 'Retail catalog response has no Items.' }
        foreach ($item in $page.Items) { $items.Add($item) }
        $uri = $page.NextPageLink
    }
    $items.ToArray()
}
