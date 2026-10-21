function Get-UtcNow {
    <#
    .SYNOPSIS
    Returns the current UTC instant through a mockable internal clock.
    #>
    [CmdletBinding()]
    [OutputType([datetimeoffset])]
    param()

    [datetimeoffset]::UtcNow
}
