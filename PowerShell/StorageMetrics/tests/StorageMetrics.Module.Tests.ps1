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
            @($format.FormatViewDefinition).Count | Should -Be 1
            $format.FormatViewDefinition[0].Control.GetType().Name | Should -Be 'TableControl'
            ($format.FormatViewDefinition[0].Control.Headers.Count -le 5) | Should -Be $true
        }
    }
}
