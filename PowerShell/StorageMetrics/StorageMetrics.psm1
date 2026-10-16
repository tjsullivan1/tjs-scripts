#Requires -Version 7.0

$script:StoragePricingPolicy = Import-PowerShellDataFile -LiteralPath "$PSScriptRoot\Data\StoragePricingPolicy.psd1" -ErrorAction Stop
$script:StorageApiMaps = @{ Blob = @{}; DataLake = @{}; GPv1 = @{} }
foreach ($mapping in @(
    @{ Target = 'Blob'; Groups = $script:StoragePricingPolicy.BlobApiGroups.Values },
    @{ Target = 'DataLake'; Groups = $script:StoragePricingPolicy.DataLakeApiGroups.Values }
)) {
    foreach ($category in $mapping.Groups.Keys) {
        foreach ($api in $mapping.Groups[$category]) {
            $script:StorageApiMaps[$mapping.Target][$api] = $category
        }
    }
}
$script:StorageApiMaps.GPv1 = $script:StorageApiMaps.Blob.Clone()
foreach ($category in $script:StoragePricingPolicy.GPv1ApiOverrides.Values.Keys) {
    foreach ($api in $script:StoragePricingPolicy.GPv1ApiOverrides.Values[$category]) {
        $script:StorageApiMaps.GPv1[$api] = $category
    }
}
foreach ($api in $script:StoragePricingPolicy.GPv1ApiOverrides.ExcludedApis) {
    $script:StorageApiMaps.GPv1.Remove($api)
}

foreach ($directory in @('Private', 'Public')) {
    foreach ($file in (Get-ChildItem -LiteralPath "$PSScriptRoot\$directory" -Filter '*.ps1' -File | Sort-Object Name)) {
        . $file.FullName
    }
}
Export-ModuleMember -Function Get-AzStorageTransactionMetric, Get-AzStorageRedundancyCost
