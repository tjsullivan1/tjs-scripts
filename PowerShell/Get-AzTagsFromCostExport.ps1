# MIT License (c) 2021 Microsoft Corporation
[CmdletBinding()]
param (
    $path_to_csv,
    $output_path = "~/Desktop/output.csv"
)

if ($path_to_csv) {
    $csv_contents = Import-Csv $path_to_csv
    $extended_output = New-Object System.Collections.ArrayList


    foreach ($rg in $csv_contents) {
        $rg_name = $rg.ResourceGroupName
        $cost = $rg.Cost
        $sub = $rg.Subscription

        try {
            $rg_details = Get-AzResourceGroup -Name $rg_name -ErrorAction Stop # | Format-Table -GroupBy Location ResourceGroupName,ProvisioningState,Tags
            $tags = $rg_details.Tags | ConvertTo-Json
            $obj = [PSCustomObject]@{ 
                ResourceGroup = $rg_name
                SubscriptionName = $sub
                Tags = $tags
                Cost = $cost
                Location = $rg_details.Location
                ID  = $rg_details.ResourceId
            } 
        } catch {
            write-warning "$rg_name does not appear to exist"
            $obj = [PSCustomObject]@{ 
                ResourceGroup = $rg_name
                SubscriptionName = $sub
                Tags = "No tags on non-existent objects"
                Cost = $cost
                Location = "Does not exist!"
                ID  = "Does not exist"
            } 
        }

        Write-Output $obj | export-csv -Path $output_path -Append

    }
} else {
    Write-Warning "Please provide a path to your CSV with the -path_to_csv parameter"
}