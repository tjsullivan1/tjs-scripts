[cmdletbinding()]
param(
    [switch]$IsTest = $False
)

if ($IsTest) {
    $locations = get-azlocation | where location -eq "eastus"
} else {
    $locations = get-azlocation
}


foreach ($loc in $locations) {
    $location = $loc.location
    write-verbose "Querying $location"
    try {
        $available = Get-AzVMUsage -location $location -ErrorAction Stop | select -expand Name | select -expand LocalizedValue
        $in_use = Get-AzVMUsage -location $location -ErrorAction Stop | where CurrentValue -gt 0 | select -expand Name | where LocalizedValue -like *Family* | select -ExpandProperty LocalizedValue
        $vms_in_region = get-azvm -location $location -ErrorAction SilentlyContinue
    } catch {
        write-verbose "$location threw an error. Potentially not registered for resource provider."
        break
    }

    foreach ($vm in $in_use) {
    $family = ($vm -split " ")[1]
    if ($family -match "v\d$") {
        write-verbose "Current VM Family $family"
        $current_iteration = $family.split('v')[1]
        write-verbose "Current iteration is $current_iteration"
        $future_iteration = [int]::Parse($current_iteration) + 1
        write-verbose "Future iteration is $future_iteration"
        $future_family = $family.replace($current_iteration, $future_iteration)
        write-verbose "Future VM Family is $future_family"
    } else {
        write-verbose "Current VM Family $family"
        $future_family = $family + "v2"
        write-verbose "Future VM Family is $future_family"
    }
    
    if ($available -match $future_family) {
        write-output "You have a vm, of type $vm with the family $family, deployed in $location that has a newer family to look into $future_family"
        $version = "v" + ($family -split 'v')[1]
        $topped = ($family -split 'v')[0]
        if ($topped.length -eq 2) {
            $fam_indicator = $topped[0]
            $prem_indicator = $true
        } else {
            $fam_indicator = $topped[0]
            $prem_indicator = $false
        }

        foreach ($vir in $vms_in_region) {
            $name = $vir.Name
            write-verbose "Testing $name"
            $size = ($vir | select -ExpandProperty HardwareProfile | select -ExpandProperty vmsize).replace('Standard_','')
            if ($prem_indicator) {
                if ($size -match "^$fam_indicator" -and $size -match "$version$" -and $size -imatch "s") {
                    write-verbose "$name is a likely candidate"
                    get-azvm -name $name | select -Property name, resourcegroupname -ExpandProperty HardwareProfile
                }
            } elseif (!($prem_indicator)) {
                if ($size -match "^$fam_indicator" -and $size -match "$version$" -and $size -inotmatch "s") {
                    write-verbose "$name is a likely candidate"
                    get-azvm -name $name | select -Property name, resourcegroupname -ExpandProperty HardwareProfile
                }
            }

        }
    }
}
}
