function Get-CostField {
    <#
    .SYNOPSIS
    Resolves known billing column aliases and rejects missing required fields.
    #>
    param([object]$Row, [string[]]$Names, [switch]$Required)
    foreach ($name in $Names) {
        $property = $Row.PSObject.Properties[$name]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }
    if ($Required) { throw "Cost details field missing: $($Names -join '/')." }
    return $null
}
