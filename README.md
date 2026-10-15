# tjs-scripts
Instead of using gists, a repo for my scripts. 

## Storage metrics

[Quickstart: one account, costs, and multiple accounts](PowerShell/StorageMetrics/Quickstart.md).

[PowerShell storage transaction collector](PowerShell/StorageMetrics/StorageTransactionMetrics.md):
collect observed Blob/ADLS requests across accounts and subscriptions, grouped by
documented operation categories, with pipeline-friendly CSV/JSON output.
Monthly totals support opt-in comparisons with actual billed usage from the
Cost Details API or existing usage-details CSV files.
Optional historical capacity averages retain tier/blob-type splits and missing-hour
coverage. Billing evidence can retain daily rows, rate/benefit context and verified
meter quantities; the collector does not calculate redundancy scenario prices.
An opt-in workload baseline separates observed and billed quantities and compares
monthly tiered capacity with billing, exposing unresolved mappings and differences.
For today's footprint, `-IncludeCurrentCapacity` adds the latest reconciled
capacity by tier with sample timestamps/age, independently of historical coverage.
A separate `Get-AzStorageRedundancyCost` command applies current public retail
rates to constant capacity and explicitly scaled requests for ZRS/GRS/GZRS/RA-GRS,
returning partial planning subtotals with unsupported/excluded charges visible.
Flat Blob remains the default. For an HNS-enabled Standard GPv2 account, use
`Get-AzStorageRedundancyCost -Records $recent -ModelMonth '2026-10' -PricingMode AdlsGen2`
for DFS workloads, or `-PricingMode BlobHns` for Blob/NFS/SFTP workloads.
Both include separate measured HNS index capacity; DFS requests remain planning
approximations because 4-MiB transfers and recursive operations can differ from
billable units. Choose the actual endpoint schedule; do not add alternative
scenario subtotals together. See the StorageMetrics quickstart for collection
and examples.
