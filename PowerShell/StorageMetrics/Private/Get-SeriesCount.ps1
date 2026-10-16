function Get-SeriesCount {
    <#
    .SYNOPSIS
    Validates a single FULL-interval request count without filling missing totals.
    #>
    param([hashtable]$Series)
    $points = @($Series['data'])
    if ($points.Count -gt 1) { throw 'Expected a single FULL interval data point per series.' }
    if ($points.Count -eq 0 -or $null -eq $points[0] -or $null -eq $points[0]['total']) { return $null }
    $number = $points[0]['total']
    if ($number -isnot [ValueType] -or $number -is [bool]) {
        throw 'Transactions Total must be numeric.'
    }
    $count = [decimal]$number
    if ($count -lt 0 -or [decimal]::Truncate($count) -ne $count) {
        throw 'Transactions Total must be a nonnegative integer.'
    }
    return $count
}
