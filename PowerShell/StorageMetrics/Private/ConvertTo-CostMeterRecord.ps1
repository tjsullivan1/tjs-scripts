function ConvertTo-CostMeterRecord {
    <#
    .SYNOPSIS
    Copies normalized billing fields into the collector's flat record schema.
    #>
    param([hashtable]$Data)
    $record = $Data.Template.PSObject.Copy()
    foreach ($field in $Data.Keys) {
        if ($field -eq 'Template') { continue }
        if ($null -ne $record.PSObject.Properties[$field]) {
            $record.$field = $Data[$field]
        } else {
            $record | Add-Member -MemberType NoteProperty -Name $field -Value $Data[$field]
        }
    }
    $record
}
