function Set-StorageRecordType {
    <#
    .SYNOPSIS
    Attaches display metadata without changing the flat export properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][object]$Record
    )
    process {
        foreach ($name in @($Record.PSObject.TypeNames)) {
            if ($name.StartsWith('StorageMetrics.', [StringComparison]::Ordinal)) {
                [void]$Record.PSObject.TypeNames.Remove($name)
            }
        }
        $Record.PSObject.TypeNames.Insert(0, "StorageMetrics.$($Record.RecordType)")
        $Record
    }
}
