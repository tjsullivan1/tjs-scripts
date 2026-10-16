function Get-ReportHeader {
    <#
    .SYNOPSIS
    Reads a named Cost Details response header.
    #>
    param([object]$Response, [string]$Name)
    foreach ($header in $Response.Headers) {
        if ($header.Key -eq $Name) { return @($header.Value)[0] }
    }
    return $null
}
