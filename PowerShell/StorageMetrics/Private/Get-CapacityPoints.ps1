function Get-CapacityPoints {
    <#
    .SYNOPSIS
    Validates hourly capacity timestamps and preserves missing sample values.
    #>
    param([hashtable]$Series, [datetimeoffset]$First, [datetimeoffset]$Last)
    $points = @{}
    foreach ($point in $Series['data']) {
        $time = [datetimeoffset]::MinValue
        if ($point['timeStamp'] -is [datetime]) {
            $time = [datetimeoffset]$point['timeStamp']
        } elseif (-not [datetimeoffset]::TryParse($point['timeStamp'], [cultureinfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$time)) {
            throw 'Capacity point has an invalid timestamp.'
        }
        $time = $time.ToUniversalTime()
        if ($time -lt $First -or $time -ge $Last -or $time.Ticks % [timespan]::TicksPerHour) {
            throw 'Capacity point is outside the requested hourly window.'
        }
        $key = $time.ToString('o')
        if ($points.ContainsKey($key)) { throw 'Duplicate capacity timestamp.' }
        $average = $point['average']
        if ($null -ne $average) {
            if ($average -isnot [ValueType] -or $average -is [bool] -or [decimal]$average -lt 0) {
                throw 'Capacity Average must be a nonnegative number.'
            }
            $average = [decimal]$average
        }
        $points[$key] = $average
    }
    return $points
}
