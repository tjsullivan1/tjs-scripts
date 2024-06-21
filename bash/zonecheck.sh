#!/bin/bash

if [ $# -lt 2 ]
then
    echo 1>&2 "$0: not enough arguments"
    echo "usage: '$0 REGION_NAME SKU_NAME'"
    exit 2
elif [ $# -gt 2 ]; then
    echo 1>&2 "$0: too many arguments"
    echo "usage: '$0 REGION_NAME SKU_NAME'"
    exit 2
fi

region=$1
sku=$2
echo $region $sku

# Get the VM info separately from just listing out restrictions to validate that we have a good response. If the SKU doesn't exist in a region, this command returns an empty set []
vm_info=`az vm list-skus --location $region --size $sku`

if [[ $vm_info == "[]" ]]
then
    echo 1>&2 "No VM Information returned for $sku in $region"
    exit 126
fi

# This command will parse the vm_info to retrieve a list of numerals representing the logical zones in a region, parse them
echo $vm_info | jq  .[].restrictions[0].restrictionInfo.zones[] | sed 's/"//g' > bad_zones.txt

# If we have two or more bad zones, we do not want to proceed. Clean up the file and throw an error code.
if [[ `wc -l < bad_zones.txt` > 1 ]]
then 
    rm bad_zones.txt
    echo 1>&2 "VM $sku in $region not available in enough zones"
    exit 75
fi 

# This command presumes that there are three logical zones in each region.
echo "1 2 3" | sed 's/\s/\n/g' > zones.txt

# This grep command will return the non-matching values from the scond file (i.e., healthy zones)
grep -Fxv -f bad_zones.txt zones.txt

# Cleanup
rm bad_zones.txt zones.txt
