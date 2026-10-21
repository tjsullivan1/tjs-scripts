@{
    PolicyVersion = '1.0.0'
    BlobApiGroups = @{
        Source = 'https://learn.microsoft.com/en-us/azure/storage/blobs/map-rest-apis-transaction-categories'
        RetrievedOn = '2026-10-14'
        Values = @{
            Reads = @('GetBlob', 'QueryBlobContents')
            Writes = @('SealBlob', 'AppendBlockThroughCopy', 'AppendBlock', 'CopyBlobFromURL',
                'CopyBlob', 'PutBlobFromURL', 'PutBlob', 'PutBlockFromURL', 'PutBlockList',
                'PutBlock', 'UndeleteBlob')
            ListAndCreateContainer = @('CreateContainer', 'FindBlobsByTags', 'ListBlobs',
                'ListContainers', 'RestoreContainer')
            Free = @('DeleteBlob', 'DeleteContainer')
            AllOtherOperations = @('AbortCopyBlob', 'SetContainerServiceMetadata',
                'GetAccountInformation', 'GetBlobMetadata', 'GetBlobProperties',
                'GetBlobServiceProperties', 'GetBlobServiceStats', 'GetBlobTags',
                'GetBlockList', 'GetContainerACL', 'GetContainerMetadata',
                'GetContainerProperties', 'GetUserDelegationKey', 'IncrementalCopyBlob',
                'AcquireBlobLease', 'ReleaseBlobLease', 'RenewBlobLease', 'BreakBlobLease',
                'ChangeBlobLease', 'AcquireContainerLease', 'ReleaseContainerLease',
                'RenewContainerLease', 'BreakContainerLease', 'ChangeContainerLease',
                'BlobPreflightRequest', 'SetBlobExpiry', 'SetBlobMetadata',
                'SetBlobProperties', 'SetBlobServiceProperties', 'SetBlobTags',
                'SetContainerACL', 'SetContainerMetadata', 'SnapshotBlob')
        }
    }
    DataLakeApiGroups = @{
        Source = 'https://learn.microsoft.com/en-us/azure/storage/blobs/map-rest-apis-transaction-categories'
        RetrievedOn = '2026-10-14'
        Values = @{
            Reads = @('GetFileProperties', 'GetPathAccessControl', 'GetPathStatus', 'ReadFile')
            Writes = @('CreateFilesystem', 'SetFilesystemProperties', 'CreatePathDir',
                'CreatePathFile', 'AppendFile', 'FlushFile', 'SetFileProperties', 'SetPathAccessControl')
            IterativeReads = @('ListFilesystems', 'ListFilesystemDir', 'ListFilesystemFile')
            IterativeWrites = @('RenamePathDir', 'RenamePathFile', 'SetPathAccessControlRecursive')
            Free = @('DeleteFilesystem', 'DeleteDirectory', 'DeleteFile')
            AllOtherOperations = @('GetFilesystemProperties', 'LeaseFile')
        }
    }
    GPv1ApiOverrides = @{
        Source = 'https://learn.microsoft.com/en-us/azure/storage/blobs/map-rest-apis-transaction-categories'
        RetrievedOn = '2026-10-14'
        Values = @{
            Reads = @('GetAccountInformation', 'GetBlobMetadata', 'GetBlobProperties',
                'GetBlobServiceProperties', 'GetBlobServiceStats', 'GetBlobTags', 'GetBlockList',
                'GetContainerACL', 'GetContainerMetadata', 'GetContainerProperties',
                'GetUserDelegationKey', 'AcquireBlobLease', 'ReleaseBlobLease', 'RenewBlobLease',
                'AcquireContainerLease', 'ReleaseContainerLease', 'RenewContainerLease',
                'BlobPreflightRequest', 'SnapshotBlob')
            Writes = @('AbortCopyBlob', 'IncrementalCopyBlob', 'BreakBlobLease',
                'ChangeBlobLease', 'BreakContainerLease', 'ChangeContainerLease', 'SetBlobExpiry',
                'SetBlobMetadata', 'SetBlobProperties', 'SetBlobServiceProperties', 'SetBlobTags',
                'SetContainerACL', 'SetContainerMetadata')
            AllOtherOperations = @('DeleteBlob', 'DeleteContainer')
        }
        ExcludedApis = @('QueryBlobContents')
    }
    MeterCategories = @{
        Source = 'https://prices.azure.com/api/retail/prices'
        RetrievedOn = '2026-10-14'
        Values = @{
            'Read Operations' = 'Reads'
            'Write Operations' = 'Writes'
            'Iterative Read Operations' = 'IterativeReads'
            'Iterative Write Operations' = 'IterativeWrites'
            'All Other Operations' = 'AllOtherOperations'
            'List and Create Container Operations' = 'ListAndCreateContainer'
        }
    }
    OperationUnitMultipliers = @{
        Source = 'https://prices.azure.com/api/retail/prices'
        RetrievedOn = '2026-10-14'
        Values = @{
            '10K' = 10000
            '10,000 Operations' = 10000
            '1 Operations' = 1
            '100' = 100
            '100 Operations' = 100
        }
    }
    QuantityKinds = @{
        Source = 'https://prices.azure.com/api/retail/prices'
        RetrievedOn = '2026-10-14'
        Values = @{
            'Data Stored' = 'Capacity'; 'Index' = 'HnsIndexCapacity'
            'Data Retrieval' = 'Retrieval'; 'Priority Data Retrieval' = 'Retrieval'
            'Early Delete' = 'EarlyDeletion'
            'Data Scanned for Query Acceleration' = 'QueryAccelerationScanned'
            'Data Returned for Query Acceleration' = 'QueryAccelerationReturned'
            'Blob Inventory' = 'InventoryObjects'; 'Index Tags' = 'IndexTags'
            'Named Encryption Scopes' = 'EncryptionScopes'
        }
        SftpMeterPattern = '^SSH File Transfer Protocol (LRS|ZRS|GRS|RA-GRS|GZRS|RA-GZRS) Hour Enabled$'
        RestoreMeterPattern = '^Point-in-time Restore (LRS|GRS) Data Processed$'
        NetworkMeters = @('Intra Continent Data Transfer Out', 'Inter Continent Data Transfer Out', 'Standard Data Transfer Out')
        GeoReplicationMeters = @('Geo-Replication Data Transfer', 'Geo-Replication v2 Data Transfer')
    }
    QuantityUnits = @{
        Source = 'https://learn.microsoft.com/en-us/azure/storage/common/storage-plan-manage-costs'
        RetrievedOn = '2026-10-14'
        Values = @{
            Capacity = @{ Units = @('1 GB/Month', 'GB/Month'); Unit = 'GiBMonth'; Multiplier = 1 }
            HnsIndexCapacity = @{ Units = @('1 GB/Month', 'GB/Month'); Unit = 'GiBMonth'; Multiplier = 1 }
            Retrieval = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            EarlyDeletion = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            GeoReplicationTransfer = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            QueryAccelerationScanned = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            QueryAccelerationReturned = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            NetworkTransfer = @{ Units = @('1 GB', 'GB'); Unit = 'BillingGB'; Multiplier = 1 }
            SftpEnabledHours = @{ Units = @('1', '1 Hour'); Unit = 'Hours'; Multiplier = 1 }
            InventoryObjects = @{ Units = @('1M'); Unit = 'Objects'; Multiplier = 1000000 }
            IndexTags = @{ Units = @('10K/Month'); Unit = 'TagMonths'; Multiplier = 10000 }
            EncryptionScopes = @{ Units = @('1/Month'); Unit = 'ScopeMonths'; Multiplier = 1 }
            RestoreDataProcessed = @{ Units = @('1 MB'); Unit = 'BillingMB'; Multiplier = 1 }
        }
    }
    RetailProducts = @{
        Source = 'https://prices.azure.com/api/retail/prices'
        RetrievedOn = '2026-10-16'
        Values = @{
            BlobFlat = @{
                Catalog = @('Blob Storage', 'General Block Blob v2')
                Default = 'Blob Storage'
                Zonal = 'General Block Blob v2'
                ZonalScenarios = @('ZRS', 'GZRS', 'RA-GZRS')
            }
            BlobHns = @{
                Catalog = @('General Block Blob v2 Hierarchical Namespace', 'Azure Data Lake Storage Gen2 Hierarchical Namespace')
                Default = 'General Block Blob v2 Hierarchical Namespace'
            }
            AdlsGen2 = @{
                Catalog = @('Azure Data Lake Storage Gen2 Hierarchical Namespace')
                Default = 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
            }
        }
        Index = 'Azure Data Lake Storage Gen2 Hierarchical Namespace'
        GeoReplication = 'Storage - Bandwidth'
    }
}
