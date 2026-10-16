# Shared retry policy for ARM GET requests in the storage metrics collectors.
function Invoke-StorageArmGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Context,
        [int]$MaxRetry = 4
    )

    $retryableStatusCodes = @(429, 500, 502, 503, 504)
    for ($retry = 0; ; $retry++) {
        $response = $null
        $errorResponse = $null
        $failure = $null
        try {
            $response = Invoke-AzRestMethod -Path $Path -Method GET -DefaultProfile $Context -ErrorAction Stop
        } catch {
            $failure = $_
            $responseProperty = $failure.Exception.PSObject.Properties['Response']
            if ($null -ne $responseProperty) {
                $errorResponse = $responseProperty.Value
                $response = $errorResponse
            }
        }

        $statusCode = $null
        if ($null -ne $response) {
            $statusProperty = $response.PSObject.Properties['StatusCode']
            if ($null -ne $statusProperty) { $statusCode = [int]$statusProperty.Value }
        }
        if ($null -eq $statusCode -and $null -ne $failure) {
            if ($null -ne $errorResponse) {
                $statusProperty = $errorResponse.PSObject.Properties['StatusCode']
                if ($null -ne $statusProperty) { $statusCode = [int]$statusProperty.Value }
            }
        }

        if ($null -eq $statusCode) {
            if ($null -ne $failure) { throw $failure }
            throw 'ARM returned a response without an HTTP status code.'
        }
        if ($statusCode -eq 200) { return $response }
        if ($statusCode -notin $retryableStatusCodes) { throw "ARM HTTP $statusCode." }
        if ($retry -ge $MaxRetry) { throw "ARM HTTP $statusCode after $MaxRetry retries." }

        $headers = $null
        if ($null -ne $response) {
            $headersProperty = $response.PSObject.Properties['Headers']
            if ($null -ne $headersProperty) { $headers = $headersProperty.Value }
        }
        if ($null -eq $headers -and $null -ne $failure) {
            if ($null -ne $errorResponse) {
                $headersProperty = $errorResponse.PSObject.Properties['Headers']
                if ($null -ne $headersProperty) { $headers = $headersProperty.Value }
            }
        }

        $retryAfter = $null
        if ($headers -is [System.Collections.IDictionary]) {
            foreach ($key in $headers.Keys) {
                if ([string]$key -ieq 'Retry-After') {
                    $retryAfter = [string]@($headers[$key])[0]
                    break
                }
            }
        } elseif ($headers -is [System.Collections.Specialized.NameValueCollection]) {
            $retryAfter = $headers.Get('Retry-After')
        } elseif ($headers -is [System.Net.Http.Headers.HttpResponseHeaders]) {
            $retryCondition = $headers.RetryAfter
            if ($null -ne $retryCondition) {
                if ($null -ne $retryCondition.Delta) {
                    $retryAfter = $retryCondition.Delta.TotalSeconds.ToString([cultureinfo]::InvariantCulture)
                } elseif ($null -ne $retryCondition.Date) {
                    $retryAfter = $retryCondition.Date.Value.ToString('o', [cultureinfo]::InvariantCulture)
                }
            }
        } elseif ($null -ne $headers) {
            $retryAfterProperty = $headers.PSObject.Properties['Retry-After']
            if ($null -eq $retryAfterProperty) { $retryAfterProperty = $headers.PSObject.Properties['RetryAfter'] }
            if ($null -ne $retryAfterProperty) { $retryAfter = [string]@($retryAfterProperty.Value)[0] }
        }

        if ($null -ne $retryAfter) {
            $retrySeconds = 0.0
            if ([double]::TryParse($retryAfter, [Globalization.NumberStyles]::Float,
                    [cultureinfo]::InvariantCulture, [ref]$retrySeconds)) {
                if ($retrySeconds -lt 0) { throw 'ARM returned an invalid Retry-After header.' }
            } else {
                $retryTime = [datetimeoffset]::MinValue
                if (-not [datetimeoffset]::TryParse($retryAfter, [cultureinfo]::InvariantCulture,
                        [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$retryTime)) {
                    throw 'ARM returned an invalid Retry-After header.'
                }
                $retrySeconds = [math]::Max(0, ($retryTime.ToUniversalTime() - [datetimeoffset]::UtcNow).TotalSeconds)
            }
        } else {
            $retrySeconds = [math]::Pow(2, $retry) + (Get-Random -Minimum 0 -Maximum 1000) / 1000.0
        }
        Start-Sleep -Seconds $retrySeconds
    }
}
