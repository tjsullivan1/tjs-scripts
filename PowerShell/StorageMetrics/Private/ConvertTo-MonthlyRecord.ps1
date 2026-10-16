function ConvertTo-MonthlyRecord {
    <#
    .SYNOPSIS
    Rolls verified request windows into bounded UTC calendar-month records.
    #>
    param([object[]]$Records, [datetimeoffset]$Start, [datetimeoffset]$End)
    foreach ($monthGroup in ($Records | Group-Object Month)) {
        $firstStart = [datetimeoffset]$monthGroup.Group[0].StartTime
        $monthStart = [datetimeoffset]::new($firstStart.Year, $firstStart.Month, 1, 0, 0, 0, [timespan]::Zero)
        $monthEnd = $monthStart.AddMonths(1)
        $periodStart = $monthStart
        $periodEnd = $monthEnd
        if ($start -gt $periodStart) { $periodStart = $start }
        if ($end -lt $periodEnd) { $periodEnd = $end }
        $incomplete = @($monthGroup.Group | Where-Object CompletenessStatus -ne 'Reconciled').Count -gt 0
        $recordGroups = $monthGroup.Group | Group-Object -CaseSensitive -Property {
            ConvertTo-Json -InputObject @(
                $_.RecordType, $_.Category, $_.ApiName, $_.ResponseType, $_.Tier,
                $_.GeoType, $_.Authentication, $_.TransactionType, $_.MappingStatus
            ) -Compress
        }
        foreach ($recordGroup in $recordGroups) {
            $record = $recordGroup.Group[0].PSObject.Copy()
            $count = [decimal]0
            $missingCount = $false
            foreach ($chunkRecord in $recordGroup.Group) {
                if ($null -eq $chunkRecord.RequestCount) {
                    $missingCount = $true
                } else {
                    $count += $chunkRecord.RequestCount
                }
            }
            $record.RequestCount = $count
            if ($missingCount) { $record.RequestCount = $null }
            $record.CountStatus = if ($missingCount) { 'MissingData' } else { 'Observed' }
            $record.CompletenessStatus = if ($incomplete) { 'UnverifiableMissingData' } else { 'Reconciled' }
            $record.StartTime = $periodStart.ToString('o')
            $record.EndTime = $periodEnd.ToString('o')
            $record.SummaryPeriod = 'Month'
            $record.IsPartialMonth = $periodStart -ne $monthStart -or $periodEnd -ne $monthEnd
            $record.QueryWindowHours = $null
            $record
        }
    }
}
