$accounts = Get-AzStorageAccount

foreach ($account in $accounts) {
    $ctx = $account.Context

    $containers = Get-AzStorageContainer -Context $ctx | select -expand Name

    foreach ($container in $containers) {
        # get a list of all of the blobs in the container 
        $listOfBlobs = Get-AzStorageBlob -Container $container -Context $ctx 

        # zero out our total
        $length = 0

        # this loops through the list of blobs and retrieves the length for each blob
        #   and adds it to the total
        $listOfBlobs | ForEach-Object {$length = $length + $_.Length}

        # output the blobs and their sizes and the total 
        $obj = [PSCustomObject]@{ 
            StorageAccount = $account.StorageAccountName
            StorageSku = $account.Sku.Name
            StorageKind = $account.Kind
            StorageDefaultTier = $account.AccessTier
            ContainerName = $container 
            SizeInMBytes = $length/1024/1024
        }

        Write-Output $obj 
    }
}
