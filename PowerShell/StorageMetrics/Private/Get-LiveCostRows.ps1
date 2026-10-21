function Get-LiveCostRows {
    <#
    .SYNOPSIS
    Retrieves every Cost Details report partition within bounded polling limits.
    #>
    param([object]$Template, [object]$Context, [int]$TimeoutMinutes)
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
    $deadline = (Get-UtcNow).AddMinutes($TimeoutMinutes)
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
        if ($pollCount -gt 30 -or (Get-UtcNow).AddSeconds($seconds) -gt $deadline) {
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
