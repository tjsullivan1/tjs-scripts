function Import-CostRows {
    <#
    .SYNOPSIS
    Imports distinct local billing CSV partitions.
    #>
    param([string[]]$Paths)
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Cost CSV not found: $path" }
        $resolved = (Resolve-Path -LiteralPath $path -ErrorAction Stop).ProviderPath
        if (-not $seen.Add($resolved)) { throw "Duplicate cost CSV: $path" }
        Import-Csv -LiteralPath $path -ErrorAction Stop
    }
}
