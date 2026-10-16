function Get-CostDecimal {
    <#
    .SYNOPSIS
    Parses billing numbers as exact decimals using invariant culture.
    #>
    param([string]$Value, [string]$Name)
    $number = [decimal]0
    if (-not [decimal]::TryParse($Value, [Globalization.NumberStyles]::Float,
            [cultureinfo]::InvariantCulture, [ref]$number)) {
        throw "Invalid cost details number in $Name."
    }
    return $number
}
