function Get-CostLookupKey {
    <#
    .SYNOPSIS
    Creates an unambiguous case-normalized billing lookup key.
    #>
    param([string]$ResourceId, [string]$Part1, [string]$Part2)
    $keyParts = @(
        ([string]$ResourceId).ToLowerInvariant()
        ([string]$Part1).ToLowerInvariant()
        ([string]$Part2).ToLowerInvariant()
    )
    ConvertTo-Json -InputObject $keyParts -Compress
}
