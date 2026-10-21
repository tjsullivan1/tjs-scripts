BeforeAll {
    $script:module = Import-Module "$PSScriptRoot\..\StorageMetrics.psd1" -Force -PassThru -ErrorAction Stop
}

Describe 'StorageMetrics module interface' {
    It 'imports only the two supported public commands' {
        ($script:module.ExportedFunctions.Keys | Sort-Object) -join ',' |
            Should -Be 'Get-AzStorageRedundancyCost,Get-AzStorageTransactionMetric'
        @($script:module.ExportedAliases.Keys).Count | Should -Be 0
        @($script:module.ExportedVariables.Keys).Count | Should -Be 0
    }

    It 'keeps private helpers outside the caller command surface' {
        @(Get-Command -Module StorageMetrics).Count | Should -Be 2
        Get-Command New-TransactionRecord -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command Get-StorageCapacityRecord -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command Get-UtcNow -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'keeps the same module instance when both compatibility shims are dot-sourced' {
        $before = Get-Module StorageMetrics
        . "$PSScriptRoot\..\Get-AzStorageTransactionMetric.ps1"
        . "$PSScriptRoot\..\Get-AzStorageRedundancyCost.ps1"
        [object]::ReferenceEquals($before, (Get-Module StorageMetrics)) | Should -Be $true
    }

    It 'registers a compact table for each documented record type' {
        $types = @(
            'AccountTotal', 'Summary', 'Detail', 'Error',
            'Capacity', 'CapacityAccountTotal', 'IndexCapacity', 'CapacityError',
            'CurrentCapacity', 'CurrentCapacityAccountTotal', 'CurrentIndexCapacity', 'CurrentCapacityError',
            'CostMeter', 'CostDetail', 'CostComparison', 'CostError',
            'Workload', 'BilledWorkload', 'CapacityComparison', 'Estimate', 'Scenario'
        )
        foreach ($type in $types) {
            $format = Get-FormatData -TypeName "StorageMetrics.$type"
            $typeView = @($format.FormatViewDefinition | Where-Object Name -eq "StorageMetrics.$type")
            $mixedView = @($format.FormatViewDefinition | Where-Object Name -eq 'StorageMetrics.Mixed')
            $typeView.Count | Should -Be 1
            $mixedView.Count | Should -Be 1
            $typeView[0].Control.GetType().Name | Should -Be 'TableControl'
            ($typeView[0].Control.Headers.Count -le 5) | Should -Be $true
            $mixedView[0].Control.GetType().Name | Should -Be 'TableControl'
            $mixedView[0].Control.Headers.Count | Should -Be 6
        }
    }

    It 'renders mixed record types in a compact table' {
        $types = @(
            'AccountTotal', 'Summary', 'Detail', 'Error',
            'Capacity', 'CapacityAccountTotal', 'IndexCapacity', 'CapacityError',
            'CurrentCapacity', 'CurrentCapacityAccountTotal', 'CurrentIndexCapacity', 'CurrentCapacityError',
            'CostMeter', 'CostDetail', 'CostComparison', 'CostError',
            'Workload', 'BilledWorkload', 'CapacityComparison', 'Estimate', 'Scenario'
        )
        $records = foreach ($type in $types) {
            $record = [pscustomobject]@{
                RecordType = $type
                StorageAccountName = 'storage'
                Month = '2026-01'
                SummaryPeriod = 'Month'
                Category = 'Reads'
                RequestCount = 10
                CompletenessStatus = 'Reconciled'
                ApiName = 'GetBlob'
                Tier = 'Hot'
                MappingStatus = 'Mapped'
                CountStatus = 'Observed'
                Message = 'example'
                BlobType = 'BlockBlob'
                AverageUsedBytes = 100
                CapacityStatus = 'CompleteSamples'
                CurrentUsedGiB = 1
                CapacitySampleTimeUtc = '2026-01-01T00:00:00Z'
                QuantityBasis = 'Sampled'
                MeterName = 'Meter'
                ActualCost = 1
                Currency = 'USD'
                BillingUsageDate = '2026-01-01'
                BilledOperationCount = 10
                ComparisonStatus = 'Compared'
                QuantityKind = 'Requests'
                QuantityUnit = 'Count'
                Quantity = 10
                QuantityStatus = 'Observed'
                ObservedCapacityGiBMonth = 1
                BilledCapacityGiBMonth = 1
                Redundancy = if ($type -eq 'Scenario') { 'ScenarioRedundancy' } else { 'EstimateRedundancy' }
                Component = if ($type -eq 'Estimate') { 'EstimateComponent' } else { $null }
                EstimatedCost = if ($type -eq 'Estimate') { 123.45 } else { $null }
                Status = 'Priced'
                PricedSubtotal = if ($type -eq 'Scenario') { 456.78 } else { $null }
                DeltaFromCurrent = if ($type -eq 'Scenario') { 12.34 } else { $null }
            }
            $record.PSObject.TypeNames.Insert(0, "StorageMetrics.$type")
            $record
        }
        $rendered = $records | Out-String -Width 300

        $rendered | Should -Match 'RecordType\s+StorageAccountName\s+Context\s+Detail\s+Value\s+Status'
        $rendered | Should -Not -Match 'RecordType\s*:'
        $rendered | Should -Match 'EstimateComponent'
        $rendered | Should -Match '123\.45'
        $rendered | Should -Match 'ScenarioRedundancy'
        $rendered | Should -Match '456\.78'
        $rendered | Should -Match '12\.34'
        foreach ($type in $types) {
            $rendered | Should -Match ([regex]::Escape($type))
        }
    }
}
