<#       
Copyright (c) Tim Sullivan. All rights reserved.
Licensed under the MIT license. See LICENSE file in the project root for full license information.
#>
<#
Creates a CSV with the name of the current subscription that contains a breakdown of all VMs with the following info:
"ResourceGroup","VMName","VM_SKU","vCPU_Core","RAM"
#>
function get-allvms {
    $vm_list = get-azvm | select HardwareProfile,ResourceGroupName,Name,Location
    $vm_list | % {
        $query = $_.HardwareProfile.VmSize
        $location = $_.Location
        $current_vm_size = get-azvmsize -location $location  | ? {$_.name -eq $query}
        $cores = $current_vm_size.NumberOfCores
        $mem = $current_vm_size.memoryinmb / 1024

        $obj = [PSCustomObject]@{
            ResourceGroup = $_.ResourceGroupName
            VMName = $_.Name
            VM_SKU = $query
            vCPU_Core = $cores
            RAM = $mem
        }

        write-output $obj
    }
}

$sub = (get-azcontext).Name.split(' (')[0].replace(' ','_')
$file_path = $sub + '.csv'

get-allvms | export-csv $file_path
