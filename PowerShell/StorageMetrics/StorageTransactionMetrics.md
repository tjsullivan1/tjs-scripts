# Storage transaction metrics

[`Get-AzStorageTransactionMetric.ps1`](Get-AzStorageTransactionMetric.ps1) collects
Azure Monitor **observed request counts** across explicitly selected storage
accounts. It returns flat `PSCustomObject` records for pipelines, CSV, JSON and
downstream scripts. It does not calculate prices. Cost Management comparisons
are optional; normal collection makes no billing requests.
Results default to **UTC calendar-month totals** per account and category.

## Scope and prerequisites

This collector queries only `Microsoft.Storage/storageAccounts/blobServices/default`.
Both Blob and Data Lake Storage APIs use that service. Files, Queue and Table
metrics are excluded; the collector never adds parent-account Transactions to
child-service Transactions. `FileStorage` accounts are rejected.

Use PowerShell 7+ and the `Az.Accounts` module:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
# Authenticate separately for each subscription/tenant you intend to collect.
Connect-AzAccount -Tenant '<tenant-id>' -Subscription '<subscription-id>'
Get-AzContext -ListAvailable
. .\PowerShell\StorageMetrics\Get-AzStorageTransactionMetric.ps1
```

The authenticated identity needs `Microsoft.Storage/storageAccounts/read` on the
accounts and `Microsoft.Insights/metrics/read` on their Blob services. **Monitoring
Reader** or **Reader**, assigned at the account, resource-group or subscription
scope, provides these management-plane permissions. Storage account keys and
Storage Blob Data Reader are not needed. Azure Monitor platform metrics do not
require diagnostic settings.

There must be exactly one saved Az context for each subscription in the supplied
IDs. Prepare those contexts before collection. Missing or ambiguous contexts
produce explicit account failures. The function passes `-DefaultProfile` to every
ARM request and never calls `Set-AzContext`, signs in, or changes context settings.
`Invoke-AzRestMethod -Path` uses the selected context's Azure environment.

## Collect multiple accounts and subscriptions

Run from the repository root. Replace the sample IDs with your accounts:

```powershell
$ids = @(
    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/analytics/providers/Microsoft.Storage/storageAccounts/lakeaccount'
    '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/apps/providers/Microsoft.Storage/storageAccounts/blobaccount'
)
# Last completed UTC calendar month.
$now = [datetimeoffset]::UtcNow
$end = [datetimeoffset]::new($now.Year, $now.Month, 1, 0, 0, 0, [timespan]::Zero)
$start = $end.AddMonths(-1)

$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime $start -EndTime $end -IncludeDetail -ErrorAction Stop)

# Or supply an explicit, minute-aligned range with UTC/offsets.
$results = @(Get-AzStorageTransactionMetric -ResourceId $ids `
    -StartTime '2026-10-01T00:00:00Z' -EndTime '2026-10-08T00:00:00Z' `
    -IncludeDetail -ErrorAction Stop)
```

`StartTime` is inclusive and `EndTime` is exclusive. Both must be whole minutes.
The start must be within the platform metric retention window (93 days), and the
end cannot be in the future. Prefer completed historical windows because recent
metrics can still arrive between the split and unsplit queries. Duplicate IDs
(including differences in casing) are collected once. Account discovery is
deliberately not implicit: passing IDs makes the subscription/account scope
auditable.

## Output and exports

Each account/month produces one `AccountTotal` and eight `Summary` rows.
With `-IncludeDetail`, it also produces one `Detail` row per distinct
API/response/tier/geo/authentication/transaction-type combination in that month.
Counts for identical dimensions are combined across verified chunks; different
dimension values are never merged.

The collector still queries and reconciles small windows, at most 24 hours by
default; `-ChunkHours 1` uses hourly queries without changing the monthly output.
Queries stop at UTC month boundaries. `-SummaryPeriod Chunk` returns the original
per-query-window records instead of monthly totals.

For arbitrary date ranges, the first/last month can be partial. `Month` identifies
the UTC calendar month, `StartTime`/`EndTime` give the actual collected range, and
`IsPartialMonth` prevents a partial or month-to-date count from looking like a
full-month total. Counts are never extrapolated. An exclusive end at the first
instant of a month does not create a row for that month.
Account configuration is read once at collection time, not reconstructed for
historical dates.

| Field | Meaning |
| --- | --- |
| `RecordType` | `Summary`, `Detail`, `AccountTotal`, `Error`; opt-in `Capacity`, `CapacityAccountTotal`, `IndexCapacity`, `CapacityError`, `CurrentCapacity`, `CurrentCapacityAccountTotal`, `CurrentIndexCapacity`, `CurrentCapacityError`, `CostComparison`, `CostMeter`, `CostDetail`, `CostError`, `Workload`, `BilledWorkload`, `CapacityComparison` |
| `SubscriptionId`, `SubscriptionName`, `ResourceGroupName`, `StorageAccountName`, `ResourceId` | Explicit account identity; subscription name from the saved context, null if unavailable |
| `MetricResourceId` | Blob service queried |
| `Location`, `AccountKind`, `SkuName`, `IsHnsEnabled`, `AccountDefaultAccessTier` | Current account configuration; SKU includes redundancy |
| `PrimaryLocation`, `SecondaryLocation`, `IsSftpEnabled`, `IsNfsV3Enabled` | Current ARM properties, null if absent; not proof of protocol usage |
| `ConfigurationObservedAtUtc`, `ConfigurationHistoryStatus` | Snapshot time and `CurrentSnapshotOnly`; configuration history is not reconstructed |
| `StartTime`, `EndTime` | Actual collected period boundaries in UTC, serialized as ISO 8601 strings |
| `SummaryPeriod` | `Month` (default) or `Chunk` |
| `Month` | UTC calendar month, `yyyy-MM`; null on errors |
| `IsPartialMonth` | Whether monthly coverage is less than the full month; null for chunk/error rows |
| `Category` | Operation category; null on account totals and errors |
| `RequestCount` | Observed Transactions Total, or null when unavailable |
| `ApiName`, `ResponseType`, `Tier`, `GeoType`, `Authentication`, `TransactionType` | Original dimension values on detail rows; null on summaries |
| `CountStatus` | `Observed`, `MissingData`, or `Failed` |
| `CompletenessStatus` | `Reconciled`, `UnverifiableMissingData`, or `Failed` |
| `MappingStatus` | Detail classification: `Documented`, `DocumentedFree`, `UnknownApi`, `AmbiguousTierChangeOrBatch`, or `UnsupportedAccount` |
| `QueryAccelerationDataScannedBytes`, `QueryAccelerationDataReturnedBytes` | Always null: the platform metrics do not expose these meters |
| `QueryAccelerationStatus` | `UnavailableInPlatformMetrics` |
| `Message` | Failure explanation on an error row |

**Never sum all record types together.** Summary, detail and account total rows
describe the same requests. Filter one record type first. Null is not zero:
`Measure-Object` would otherwise silently exclude unknown counts.

```powershell
$results | Export-Csv -LiteralPath .\storage-transactions.csv -NoTypeInformation
ConvertTo-Json -InputObject $results -Depth 4 |
    Set-Content -LiteralPath .\storage-transactions.json -Encoding utf8

# Only combine category summaries after checking every account and period.
if (@($results | Where-Object {
    $_.RecordType -eq 'Error' -or
    ($_.RecordType -in @('AccountTotal', 'Summary', 'Detail') -and $_.CompletenessStatus -ne 'Reconciled')
}).Count) {
    throw 'At least one account/period is failed or incomplete; do not aggregate.'
}
$results | Where-Object RecordType -eq 'Summary' |
    Group-Object ResourceId, Month, Category |
    ForEach-Object {
        [pscustomobject]@{
            SubscriptionId = $_.Group[0].SubscriptionId
            StorageAccountName = $_.Group[0].StorageAccountName
            ResourceId = $_.Group[0].ResourceId
            Month = $_.Group[0].Month
            Category = $_.Group[0].Category
            ObservedRequestCount = ($_.Group | Measure-Object RequestCount -Sum).Sum
        }
    }

# Audit unmapped APIs, failures and tiers using detailed records.
$results | Where-Object { $_.RecordType -eq 'Detail' -and $_.Category -eq 'Unmapped' }
$results | Where-Object { $_.RecordType -eq 'Detail' -and $_.ResponseType -ne 'Success' }
```

CSV represents null as an empty cell; JSON preserves `null` explicitly.
To see just the total transactions per account/month, filter
`$results | Where-Object RecordType -eq 'AccountTotal'`. Do not add category
summaries to those totals.

## Current footprint and recent workload

Use `-IncludeCurrentCapacity` when the goal is today's footprint rather than
exact historical bill reconciliation. It uses the same authentication and RBAC,
requires no billing source, and does not enable historical capacity collection.
Current account attributes accompany each row.

```powershell
$end = [datetimeoffset]::UtcNow
$end = $end.AddTicks(-($end.Ticks % [timespan]::TicksPerHour))
$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime $end.AddDays(-30) -EndTime $end `
    -IncludeDetail -IncludeCurrentCapacity -ErrorAction Stop)
$results | Where-Object RecordType -eq 'CurrentCapacity' |
    Select-Object StorageAccountName, Location, AccountKind, SkuName,
        IsHnsEnabled, AccountDefaultAccessTier, Tier, BlobType,
        CurrentUsedBytes, CurrentUsedGiB, CapacitySampleTimeUtc,
        CapacitySampleAgeHours, CapacityStatus
$results | Export-Csv .\storage-current-workload.csv -NoTypeInformation
ConvertTo-Json -InputObject $results -Depth 5 |
    Set-Content .\storage-current-workload.json -Encoding utf8
```

The snapshot queries the last 24 complete UTC hours, independently of the
transaction `StartTime`/`EndTime`. It selects the latest common numeric hourly
sample across all returned Blob tier/type series and the unsplit total. Split
values must reconcile with the total. It does not average the last day's capacity,
fill missing samples, or use incomplete historical averages. If the newest
sample is missing, it selects an earlier reconciled sample and exposes its age.
Azure recomputes capacity periodically; the sample is not a real-time blob listing.

| Snapshot field | Meaning |
| --- | --- |
| `RecordType` | `CurrentCapacity`: tier/type splits; `CurrentCapacityAccountTotal`: overlapping Blob total; `CurrentIndexCapacity`: separate HNS index; `CurrentCapacityError`: collection failed |
| `CurrentUsedBytes`, `CurrentUsedGiB` | Latest usable sample in bytes and binary GiB; null when unavailable |
| `CapacitySampleTimeUtc`, `CapacitySampleAgeHours` | Selected hourly sample timestamp and age at collection; index can have a different timestamp |
| `CapacityStatus` | `LatestReconciledSample` for Blob, `LatestSample` for index, `Unavailable` when no usable sample exists, or `Failed` |
| `SummaryPeriod`, `Month` | `Snapshot` and null; these rows do not represent a billing month |
| `StartTime`, `EndTime` | Snapshot search window, not transaction period |
| `QuantityBasis`, `CompletenessStatus` | `AzureMonitorLatestUsedCapacity` and `SnapshotNotMonthlyCoverage` |

Filter snapshot splits **or** the snapshot total; do not sum both, or combine
snapshots with historical capacity rows. Snapshot `AverageUsedBytes` remains
null. Raw tier labels remain unchanged, including GPv1 `Untiered`.

This supports a practical current-footprint model: explicitly assume current
capacity remains constant for the modeled month, and use measured recent
transaction volumes with their real coverage dates. A trailing 30-day range can
span two calendar-month rows; it is not automatically a calendar-month total.
Any full-month run-rate extrapolation belongs in the pricing assumptions, not
the collector. A small billing variance can be accepted as a modeling tolerance
without changing measured quantities or claiming exact invoice validation.
The collector does not assign an arbitrary discrepancy threshold.

Retrieval, replication transfer, early deletion and query acceleration still
require billing or additional telemetry where applicable; unavailable is not
zero. This mode reports current workload inputs, not priced redundancy scenarios.

## Public retail redundancy planning estimates

[`Get-AzStorageRedundancyCost.ps1`](Get-AzStorageRedundancyCost.ps1) is a separate
pricing command. It consumes the collector's **typed objects or JSON**, not CSV
strings, and fetches current public USD consumption prices from the unauthenticated
[Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices).
Only public region/product filters are sent; resource identities and quantities
stay local. No prices are hard-coded into either script.

```powershell
. .\PowerShell\StorageMetrics\Get-AzStorageRedundancyCost.ps1
# $results from IncludeDetail + IncludeCurrentCapacity above.
$estimate = @(Get-AzStorageRedundancyCost -Records $results -ModelMonth '2026-10')
$estimate | Where-Object RecordType -eq 'Scenario' |
    Select-Object StorageAccountName, Redundancy, Currency, PricedSubtotal,
        Status, UnpricedComponents, ExcludedCharges
$estimate | Export-Csv .\storage-redundancy-estimate.csv -NoTypeInformation
ConvertTo-Json -InputObject $estimate -Depth 6 |
    Set-Content .\storage-redundancy-estimate.json -Encoding utf8
```

The planning assumptions are explicit:

- Hold the latest sampled capacity constant for the modeled calendar month.
- Scale observed request counts by modeled-month hours divided by the actual
  contiguous observed-window hours. Identical quantities are used for each SKU.
  This assumes the measured activity is representative. Failed requests remain
  in the estimate; request-based operations are not exact billed counts.
- Use current retail prices, even if `ModelMonth` is historical. Historical
  invoice validation is not performed. Rates, meter IDs, effective dates, volume
  bands and fetch timestamps are retained.
- Model standard flat-namespace block/append Blob accounts using `Blob Storage`
  for GRS/RA-GRS and `General Block Blob v2` for ZRS/GZRS. Premium, page blobs,
  HNS/DFS endpoint schedules and unresolved access tiers remain unpriced.
- Apply graduated capacity volume bands **per account/tier**, not across the
  subscription. A different contractual aggregation scope requires a separate
  adjustment. Rates/benefits never change the measured quantities.

The command validates contiguous/nonoverlapping transaction periods and that
Detail counts reconcile with AccountTotal. It rejects duplicate snapshot splits
and mixed snapshot timestamps. Collector summaries, historical capacity rows,
billing rows and overlapping snapshot totals are not priced again. Empty request
detail is accepted as observed zero only when reconciled AccountTotal is zero.

For a GPv1-to-GPv2 projection, choose `-LegacyTargetTier Hot` (or another explicit
tier). This is a migration/pricing assumption, not a claim that GPv1 has a Hot
tier. When ARM omits `IsHnsEnabled`, the command leaves the account unsupported
unless you explicitly choose `-AssumeFlatNamespace`; it never overrides known
HNS-enabled accounts. Both assumptions are recorded on output rows:

```powershell
# Explicit planning assumptions, not changes to Azure resources.
$estimate = @(Get-AzStorageRedundancyCost -Records $results `
    -ModelMonth '2026-10' -LegacyTargetTier Hot -AssumeFlatNamespace)
```

Archive under ZRS/GZRS and measured secondary reads under non-RA options mark the
scenario `Ineligible`. A catalog entry does not prove deployment eligibility in
the region; confirm Azure support and your recovery requirements separately.
Unknown APIs, iterative/size-dependent operations, missing rates, ambiguous
catalog identities and unavailable inputs remain unpriced with warnings.
Regional non-primary reference meters are retained where the retail catalog
publishes operation prices that way; their primary flags remain in rate evidence.
HTTP, invalid catalog and pagination failures terminate explicitly.

| Pricing output | Meaning |
| --- | --- |
| `RecordType` | `Estimate`: individual capacity/request component; `Scenario`: account/SKU subtotal |
| `Redundancy`, `TargetAccountKind`, `ModelMonth` | ZRS, GRS, GZRS or RA-GRS; modeled GPv2 account and month |
| `Quantity`, `QuantityUnit`, `QuantityBasis` | Constant GiBMonth capacity or scaled EstimatedOperations, with the assumption identified |
| `SourceStartTime`, `SourceEndTime`, `ScaleFactor` | Observed request coverage and explicit monthly scaling factor |
| `CapacitySampleTimeUtc` | Capacity sample used; not a historical monthly average |
| `NamespaceBasis`, `LegacyTargetTierAssumption` | Current namespace evidence or explicitly selected model assumptions |
| `ProductName`, `SkuName`, `MeterName`, `MeterId`, `RateBandsJson`, `PricesObservedAtUtc` | Exact catalog selection and dated price evidence |
| `EstimatedCost` | Priced line cost in USD; null for an unpriced line |
| `PricedSubtotal` | Sum of priced lines only; null if nothing was priced |
| `TotalRecurringCost`, `OneTimeCost` | Always null: a subtotal does not establish full recurring or conversion costs |
| `Status`, `UnpricedComponents`, `ExcludedCharges` | Planning/partial/ineligible status, unresolved lines and excluded charge components |

**These are partial planning estimates**, not complete monthly bills. Retrieval,
network bandwidth, geo-replication transfer, early deletion, features, one-time
migration/conversion costs, discounts, reservations and taxes are excluded
explicitly, not set to zero. Never sum line estimates and scenario subtotals.
The currently selected small subscription is suitable for smoke-checking the
report, not validating every account type or feature.

The October 14 live pricing check used the saved four-account current footprint
and seven-day observed requests, modeled October's 31 days. For demonstration,
it explicitly selected GPv2 Hot for GPv1 projections and assumed flat namespace
only where ARM omitted the HNS property. It produced 16 scenario rows and priced
all supported capacity/read/other-operation inputs. The 22 `Unknown` API
requests on `samnsigs001` remained unpriced, as did the excluded charges listed
above. These choices are planning assumptions, not independently verified
historical configuration or a complete current-state invoice reconciliation.
Retail prices support commercial Azure; sovereign-cloud catalogs are outside
this command's scope.

## Historical capacity for pricing preparation

Add `-IncludeCapacity` to collect used capacity for the same historical range.
Keep `StorageCapacityMetrics.ps1` beside the main script. The same Az contexts,
management-plane RBAC and 93-day retention limit apply. This mode requires
whole-hour start/end boundaries; ordinary transaction collection still accepts
whole minutes.

```powershell
$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime $start -EndTime $end -IncludeDetail -IncludeCapacity `
    -CostDetailsCsv @('.\cost-part1.csv', '.\cost-part2.csv') `
    -IncludeCostDetail -ErrorAction Stop)

$results | Where-Object RecordType -eq 'Capacity' |
    Select-Object StorageAccountName, Month, Tier, BlobType, AverageUsedBytes,
        ExpectedHours, ObservedHours, MissingHours, CapacityStatus
$results | Where-Object RecordType -eq 'CostDetail' |
    Export-Csv .\storage-billing-evidence.csv -NoTypeInformation
$results | Export-Csv .\storage-workload.csv -NoTypeInformation
ConvertTo-Json -InputObject $results -Depth 4 |
    Set-Content .\storage-workload.json -Encoding utf8
```

The collector requests `BlobCapacity` with **Average** aggregation and `PT1H`
intervals, split by `Tier` and `BlobType`, and a separate unsplit Blob-service
series. For accounts with `IsHnsEnabled = true`, it also requests `IndexCapacity`
without dimensions. It does not use parent `UsedCapacity` (which includes other
storage services), `BlobProvisionedSize`, or a current listing of blob lengths.

| Capacity field | Meaning |
| --- | --- |
| `RecordType` | `Capacity`: tier/blob-type used capacity; `CapacityAccountTotal`: overlapping unsplit total; `IndexCapacity`: separate HNS index space |
| `MetricName`, `Tier`, `BlobType` | Exact metric and original split dimensions; index/total dimensions are null |
| `ObservedByteHours` | Integral of available hourly averages, one hour per sample; null if none |
| `AverageObservedBytes` | Average over available hours only; can describe an incomplete dataset |
| `AverageUsedBytes` | Period average only when all expected hours are numeric and Blob split/unsplit reconciliation is complete; otherwise null |
| `ExpectedHours`, `ObservedHours`, `MissingHours` | Coverage of the actual requested month/chunk, including explicit null and absent points |
| `CapacityStatus` | `CompleteSamples`, `IncompleteSamples`, or `Failed` |
| `CapacityReconciliationStatus` | `ReconciledSamples`, `MissingSamples`, or `NotApplicable` for index |
| `QuantityBasis` | `AzureMonitorSampledUsedCapacity`, not an assertion of billable capacity |

Monthly output weights hourly samples, not query-window averages. An incomplete
chunk or missing tier series is never filled with zero or carried forward.
An empty successful response produces an unavailable `Capacity` row with null
dimensions and average, not a confirmed zero. Missing tiers are not emitted as
zero rows. An explicit numeric zero is retained as zero.
`-SummaryPeriod Chunk` produces capacity records per query window instead.

Each available hour's split sum is checked against the unsplit average.
The tolerance is the larger of one byte or one part per billion of the total,
to accommodate numeric rounding. Duplicate series/timestamps, unexpected
dimensions/units/intervals, a reached series cap, out-of-window points and
reconciliation mismatches fail explicitly. Missing points produce warnings and
coverage statuses instead. `CapacityError` discards buffered capacity output
for the account, but does not discard its already collected transactions or
prevent billing comparisons under nonterminating error handling.
`-ErrorAction Stop` terminates on a capacity failure.

Microsoft's [metric reference](https://learn.microsoft.com/en-us/azure/storage/blobs/monitor-blob-storage-reference)
documents these dimensions, but capacity is recomputed multiple times daily,
not refreshed every hour. Even `CompleteSamples` is a sampled used-capacity
estimate, not a complete billing ledger. Keep HNS index separate from Blob data.
Convert Blob capacity bytes to GiB using 1,073,741,824 bytes per GiB, and use
the actual calendar-month duration for proration. Do not treat available-hour
averages as a complete month's capacity, or use account default tier as a
substitute for observed tier distribution.

## Normalized monthly workload baseline

Use `-IncludeWorkloadBaseline` with an explicit billing source
(`-IncludeCostComparison` or `-CostDetailsCsv`) to append normalized quantities
and capacity comparisons. It automatically includes transaction Detail and
capacity collection, so pricing dimensions cannot be lost by forgetting those
switches. It requires completed UTC calendar months with `SummaryPeriod Month`.
Keep `StorageWorkloadBaseline.ps1` beside the main script.

```powershell
$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime $start -EndTime $end -IncludeWorkloadBaseline `
    -CostDetailsCsv @('.\cost-part1.csv', '.\cost-part2.csv') `
    -IncludeCostDetail -ErrorAction Stop)

$results | Where-Object RecordType -eq 'Workload' |
    Select-Object StorageAccountName, Month, QuantityKind, Category,
        ApiName, ResponseType, Tier, BlobType, GeoType,
        Quantity, QuantityUnit, QuantitySource, QuantityStatus |
    Export-Csv .\storage-measured-workload.csv -NoTypeInformation
$results | Where-Object RecordType -eq 'BilledWorkload' |
    Export-Csv .\storage-billed-workload.csv -NoTypeInformation
$results | Where-Object RecordType -eq 'CapacityComparison' |
    Select-Object StorageAccountName, Month, QuantityKind, Tier,
        ObservedCapacityGiBMonth, BilledCapacityGiBMonth,
        CapacityDifferenceGiBMonth, CapacityDifferencePercent,
        CapacityStatus, BillingCoverageStatus, ComparisonStatus
```

No additional Azure API or permissions are needed beyond the underlying
transaction, capacity and billing modes. The baseline does not fetch prices,
multiply a bill by redundancy factors, or convert an observed request into a
billable operation. It retains current resource snapshot metadata but cannot
establish historical configuration or the Blob/DFS endpoint pricing schedule.

| Baseline field | Meaning |
| --- | --- |
| `RecordType` | `Workload`: measured quantities; `BilledWorkload`: reported billing quantities; `CapacityComparison`: quantity diagnostics, not calculated costs |
| `SourceRecordType` | Original `Detail`, `Capacity`, `IndexCapacity` or `CostMeter` behind a normalized row |
| `QuantityKind` | Measured `ObservedRequests`, `UsedCapacity`, `HnsIndexCapacity`; billed rows retain meter kind or `UnclassifiedMeter` |
| `Quantity`, `QuantityUnit` | Available normalized quantity and unit; null quantity when missing, unverified, non-Usage, or negative adjustments need review |
| `QuantitySource`, `QuantityBasis` | Separates Azure Monitor observations from CSV/API billing evidence; billing is not independent workload telemetry |
| `QuantityStatus` | Measured `ObservedRequestsNotBillable`, `DocumentedFreeRequests`, `UnmappedRequests`, `CompleteSampleEstimate`, or `MissingData`; billed `BillingDerived`, `Unclassified`, `UnverifiedUnit`, `UnmappedOperationMeter`, `NonUsageCharge`, or `BillingAdjustmentsPresent`; comparison `ComparisonOnly` |
| `ObservedCapacityGiBMonth`, `BilledCapacityGiBMonth` | Comparable measured estimate and reported capacity usage; neither is synthesized from cost |
| `CapacityDifferenceGiBMonth`, `CapacityDifferencePercent` | Observed minus billed; percentage relative to billed quantity; null for blocked comparisons or a zero percentage denominator |
| `HasNegativeUsageQuantity` | Whether a billing aggregate contains any negative Usage row, even when its net quantity is positive |
| `CapacityTierBasis` | `ExplicitMetricTier`, `NonTieredGPv1`, or `Unresolved` on normalized Blob capacity/comparisons; raw metric and billing tier labels remain unchanged |

For a full month, normalized sampled capacity is the time-weighted monthly
average in bytes divided by **1,073,741,824**, giving GiBMonth for that month.
No fixed 30-day month, decimal-GB conversion, physical-replica multiplier or
partial-month extrapolation is used. HNS index space is a separate quantity.

Request rows retain each monthly API/category/response/tier/geo/authentication/
transaction-type combination. Failed requests remain visible; their presence
does not establish billability. Unknown and documented free operations remain
separate. A missing month count yields null normalized requests, not a partial
sum presented as complete.

Only original Detail, Capacity, IndexCapacity and CostMeter records generate
normalized rows. AccountTotal/Summary, CapacityAccountTotal, CostDetail and
CostComparison are not included again. **Original and normalized rows overlap.**
Filter a record type, quantity kind/unit and source before aggregating; do not
add `Workload` to `BilledWorkload`, sum different units, or sum both original
and normalized costs.

Capacity diagnostics group by account, month and observed/billed access tier.
They sum comparable BlockBlob/AppendBlob splits within the tier; PageBlob or
unknown blob types are blocked because the recognized billing meters describe
block-blob capacity. HNS index is compared separately, without inventing its
metric tier. Rates and benefit coverage do not change quantities; disjoint
meter/rate/benefit rows can contribute to the same quantity comparison.

There is one explicitly non-tiered case: standard GPv1 accounts (`AccountKind =
Storage`) whose capacity series are all labeled `Untiered`. Their untiered
capacity can be compared with unlabeled `General Block Blob` capacity meters.
GPv1 does not support Blob access tiers, so these quantities are not assigned
to Hot. Modern/unknown catalog meters do not receive this exception. This uses
the observed account snapshot and catalog evidence, not reconstructed account
history; a GPv1-to-GPv2 pricing change still needs separate review. See
[GPv1 migration and pricing differences](https://learn.microsoft.com/en-us/azure/storage/common/general-purpose-version-1-account-migration-overview).

| `CapacityComparison.ComparisonStatus` | Meaning |
| --- | --- |
| `QuantitiesMatch` / `QuantitiesDiffer` | Exact numeric equality/difference of available quantities; neither validates prices or final billing coverage |
| `NoMatchingBillingMeter` | Complete sampled capacity exists, but no matching Usage capacity meter was returned; billed quantity remains null |
| `MetricsIncomplete` | Complete sampled capacity is unavailable; billed quantities can remain available |
| `MetricsFailed` / `BillingUnavailable` | An underlying capacity query or billing request/import failed; inspect original error records |
| `TierUnresolved` | Missing or unsupported tier, including `Untiered` outside the verified GPv1 case; account default tier is never substituted |
| `UnsupportedBlobType` | The metric contains a blob type outside the recognized block-blob meter scope |
| `UnverifiedUnit` | At least one matching billing meter lacks a verified GiBMonth conversion; billed comparison quantity remains null |
| `AmbiguousBillingContext` | Different currency, meter-region or redundancy contexts would be combined; billed comparison quantity remains null |
| `BillingAdjustmentsPresent` | Negative Usage corrections require review; the raw/net billed evidence is retained but not exposed as usable baseline quantity |

`CapacityStatus` records sample completeness separately. Comparison rows use
`CompletenessStatus = NotBillingValidation`: Monitor reconciliation is not
inherited as a claim about billing. An unresolved tier or failed source can
coexist with incomplete samples; inspect the original rows for all underlying
issues. Refund/Purchase charges remain billing evidence but are excluded from
usage quantity comparisons. Missing billing meters never become confirmed zeros.
No percentage threshold is used to declare a baseline validated.

## Cross-checking Cost Management

Use `-IncludeCostComparison` for a live **actual-cost** report, or
`-CostDetailsCsv` for existing actual-cost usage-details CSV files. Both retain
the Monitor records and append separate billing/comparison records. CSV input
takes precedence if both parameters are specified. Keep
`StorageTransactionCostComparison.ps1` beside the main script; it is loaded
only when comparison is requested.

Comparisons require completed UTC calendar months and `-SummaryPeriod Month`.
The same 93-day Monitor retention limit applies. Each month is queried
separately, with one report per subscription/month, not per storage account.

```powershell
# Live Cost Details API (requires cost-data access).
$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime '2026-09-01T00:00:00Z' -EndTime '2026-10-01T00:00:00Z' `
    -IncludeDetail -IncludeCostComparison -ErrorAction Stop)

# Offline billing source; Monitor metrics still use the existing Az contexts.
# Include EVERY CSV partition from one actual-cost report/export, exactly once.
$results = @($ids | Get-AzStorageTransactionMetric `
    -StartTime '2026-09-01T00:00:00Z' -EndTime '2026-10-01T00:00:00Z' `
    -IncludeDetail -CostDetailsCsv @('.\cost-part1.csv', '.\cost-part2.csv') `
    -ErrorAction Stop)

$results | Where-Object RecordType -eq 'CostComparison' |
    Select-Object StorageAccountName, Month, Category, RequestCount,
        BilledOperationCount, RequestMinusBilledCount, ActualCost, Currency,
        ComparisonStatus
$results | Export-Csv .\storage-cost-comparison.csv -NoTypeInformation
```

CSV input supports standard Cost Management usage-details columns, not a
Cost Analysis pivot or FOCUS export. It reads `ResourceId`/`InstanceId`,
`Date`/`UsageDate`/`UsageStart`/`UsageDateTime`, `MeterId`, `MeterName`, `MeterSubCategory`,
`Quantity`/`UsageQuantity`, `UnitOfMeasure`, `ChargeType`,
`CostInBillingCurrency`/`Cost`/`PreTaxCost`, and
`BillingCurrency`/`BillingCurrencyCode`/`Currency`.
`ProductName`/`Product` is preserved when present. Dates must be ISO dates,
ISO offset timestamps, or US `MM/dd/yyyy` dates; numbers use invariant decimal
notation. Supply actual-cost data, not amortized data. The importer cannot
prove that a hand-supplied export has all partitions or days.
Do not mix overlapping reports. Duplicate paths are rejected, but different
files containing overlapping charges cannot be reliably deduplicated without
stable charge IDs.

Live retrieval uses the asynchronous Cost Details report API. It honors
`Retry-After`, limits polling to 30 attempts/10 minutes per report, validates
ARM polling locations, checks the CSV manifest and downloads every partition.
Uncompressed CSV reports are supported. Signed download URLs are not output
or persisted, and temporary CSV downloads are deleted even on failure.
The function does not create storage accounts, scheduled exports or diagnostic
settings, and does not change the selected Az context.

The data access route depends on the billing offer:

- For Visual Studio or MOSP/pay-as-you-go billing offers, Microsoft recommends
  [Exports or the Consumption Usage Details API](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/get-usage-details-legacy-customer).
  The newer Cost Details report API does not currently support those offers.
  A portal usage-details download is also suitable for a one-off comparison;
  an existing export avoids creating new resources.
- For EA/MCA, the [Cost Details report API](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/get-small-usage-datasets-on-demand)
  generates an asynchronous downloadable report. Automation must poll with
  `Retry-After` and read every report partition. Exports are another option.

Do not choose the API solely from the subscription's display name or
`PayAsYouGo` quota label. The live `mnsigs` check returned modern billing data
and successfully generated a Cost Details report despite that quota label.
The script tries only the report API; unsupported offers fail explicitly with
guidance to provide CSV. It does not silently fall back to the Consumption API.

The identity needs [cost-data read access](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data),
typically Cost Management Reader at subscription scope, with any required
EA/MCA billing visibility settings enabled. Azure Monitor permissions alone
do not establish this access. Reading an export from Blob Storage additionally
requires data-plane read access to its destination. Creating a scheduled export
requires export-management and destination-storage permissions; a CSV importer
does not.

A comparison uses these rules:

1. Read the offer-specific [usage fields](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/understand-usage-details-fields):
   resource ID (`ResourceId`/`InstanceId`), usage date/range, `MeterId`,
   `MeterName`, meter subcategory/product, `Quantity`/`UsageQuantity`,
   `UnitOfMeasure`, charge type and, optionally, actual cost and currency.
2. Match the exact accounts and UTC usage period; filter Blob/ADLS operation
   meters rather than including Files/Queue/Table, capacity, retrieval or
   networking charges. Preserve tier, redundancy, region and meter identity.
3. Verify the units for each meter before normalizing billed quantities into
   transaction counts. Never assume every operation meter has a 10,000-operation
   unit, or derive quantities by dividing cost by calculator prices. Query
   acceleration scanned/returned meters, if present, remain separate byte/data
   quantities with their own verified units.
4. Report observed requests and normalized billed quantities side by side,
   with differences and mapping/coverage status. Keep unknown meters and missing
   data visible rather than treating them as zero. Use a settled historical month
   and account for late usage, refunds/corrections, credits and offer-specific
   reporting dates. Platform metrics cover only the last 93 days, so older months
   need previously saved metric results.

Exact equality is not expected: Azure Monitor includes failed/free requests,
and ADLS size-based charging, iterative operations and other billing rules can
produce multiple billed transactions from one request. Keep response/tier
details for diagnosis rather than applying an invented billability filter.
The billed query-acceleration quantities can validate those costs even though
Azure Monitor cannot supply the corresponding byte counts.

### Comparison records and limitations

`CostMeter` rows retain every selected-account meter, including capacity,
bandwidth, Defender, refunds and unknown operations. They combine only rows
with the same account/month, meter ID/name, subcategory/product, unit, currency
and charge type, and identical retained region, service, pricing/benefit, rate,
invoice and period context. `BilledQuantity` is the original meter quantity; `ActualCost`
is the sum of reported costs in `Currency`, before credits/taxes as defined by
Cost Management. These are not calculated from retail prices.

The first mapping supports exact read, write, iterative read/write, other,
and list/create-container operation names in `Blob Storage`,
`General Block Blob`, and `Azure Data Lake Storage Gen2` subcategories.
Known leading access-tier/redundancy labels are stripped for this mapping;
other names remain unmapped. `General Block Blob v2` is also recognized.
Supported operation units are `10K`, `10,000 Operations`, `1 Operations`,
`100`, and `100 Operations`; per-100 iterative write units occur in the public
Azure catalog. Unknown units remain unconverted.
For example, `Standard Transactions` in `Microsoft Defender for Storage`
is a separate charge, not a Blob operation count.

`CostComparison` rows compare one observed account/month/category total with
the sum of its mapped **Usage** meters, separately by billing currency.
The observed category count spans all tiers; use the `CostMeter` and `Detail`
rows to investigate tier/response differences. If multiple currencies occur,
the observed count is repeated for each currency, not divided between them.
Do not add those repeated observed counts.

Additional flat fields are present (null on ordinary metric rows):

| Field | Meaning |
| --- | --- |
| `BilledQuantity`, `UnitOfMeasure` | Raw billed quantity/unit on meter rows |
| `BilledOperationCount` | Quantity normalized using a verified operation unit; null for other/unknown units |
| `RequestMinusBilledCount` | Observed requests minus normalized billed operations, only when comparable |
| `ActualCost`, `Currency` | Reported actual cost; never combine currencies without conversion |
| `MeterId`, `MeterName`, `MeterSubCategory`, `ProductName`, `ChargeType` | Billing identity/context on meter rows |
| `CostSource` | `CostDetailsApi` or `Csv` |
| `ComparisonStatus` | Comparison/mapping outcome |
| `BillingUsageDate` | Original daily UTC usage date on opt-in `CostDetail` rows; null on monthly `CostMeter` aggregates |
| `MeterRegion`, `BillingResourceLocation`, `MeterCategory`, `ConsumedService`, `PublisherType`, `ProductId` | Billing context, distinct from the current resource snapshot |
| `PricingModel`, `ReservationId`, `BenefitId` | Financial coverage metadata; never reduces measured quantities |
| `EffectivePrice`, `UnitPrice`, `PayGPrice`, `PricingCurrency`, `ExchangeRatePricingToBilling` | Available reported rates and currency basis; null if absent, not inferred from costs |
| `ChargeFrequency`, `CostAllocationRuleName`, `InvoiceId`, billing/service period start/end dates | Reported chargeback, invoice and period context; frequency does not prove recurring versus migration usage |
| `BillingQuantityKind`, `BillingTier`, `BillingRedundancy` | Recognized meter semantics and leading catalog labels; unknowns remain null |
| `NormalizedBilledQuantity`, `NormalizedBilledUnit`, `BillingMappingStatus` | Verified unit conversion or `UnverifiedUnit`/`Unclassified`; raw quantity/unit always retained |
| `BillingCoverageStatus` | `CsvCoverageUnverified` or `ReportPartitionsRead`; neither guarantees final invoice completeness |
| `HasNegativeUsageQuantity` | True if any constituent Usage row has a negative quantity; preserved through monthly meter aggregation |

Comparison statuses are `CountsMatch`, `CountsDiffer`, `MetricsIncomplete`,
`NoMatchingBillingMeter`, or `UnverifiedUnit`. A missing meter means null billed
count/cost, **not** a confirmed zero. `CountsMatch` means numerical equality for
the mapped meters, not proof of complete billability modeling.
Meter statuses are `VerifiedOperationUnit`, `UnverifiedUnit`,
`UnmappedOperationMeter`, `NotOperationMeter`, or `NonUsageCharge`.
Unknown operation meters stay visible and are not guessed into categories.
Refunds/other charge types remain meter rows and are not subtracted from Usage
operation comparisons.

Use `-IncludeCostDetail` with either billing mode to retain every matched
daily report row as `CostDetail`, without merging rows. It is opt-in because it
can considerably increase output size. These rows preserve zero-cost reservation
usage and rates/benefits when present. Missing optional financial metadata stays
null; malformed numeric rates fail rather than silently disappearing.
`UsageDateTime` is supported for legacy usage files. `EffectivePrice` also accepts
the legacy `ResourceRate`, and `PayGPrice` accepts `pay-as-you-goPrice`.

The exact-name meter registry recognizes Blob data/index capacity, retrieval
(including priority retrieval), early deletion, query acceleration scanned/returned,
inventory objects, index tags, encryption scopes, SFTP hours, restore data,
and verified geo-replication/network transfer names. Catalog context excludes
Defender, Files, Queue and Table from Blob quantity mappings. Unrecognized features
such as a new change-feed meter remain raw and `Unclassified`; a familiar-looking
name alone is not enough to guess its quantity.

Capacity/index `1 GB/Month` is normalized to **GiBMonth**, following Microsoft's
[binary Blob capacity billing units](https://learn.microsoft.com/en-us/azure/storage/common/storage-plan-manage-costs).
Operation units become Operations; inventory `1M` becomes Objects; index tags
`10K/Month` become TagMonths; encryption `1/Month` becomes ScopeMonths; verified
SFTP hour meters become Hours. Other `1 GB`/`1 MB` meters retain **BillingGB** or
**BillingMB** rather than assuming a byte conversion. Query-acceleration billing
quantities remain separate from Monitor's unavailable byte observations.
Early-delete GB does not reconstruct object retention or remaining byte-days.
Geo-transfer quantities describe the billed current configuration, not a measured
logical mutation volume reusable for a currently non-geo account.

Billing records use their own coverage status rather than inheriting Monitor's
`Reconciled` status. Reading every live report partition establishes report
retrieval, not finality, account-wide cost attribution or complete workload
measurement. Unassigned charges, reservation purchases and charges on other
resources remain outside selected-account quantities.

Cost failures write to the error stream and emit `CostError` rows with
`ComparisonStatus: Failed` and the failure message. They do not discard valid
Monitor records. A failed subscription/month emits no partial cost comparisons.
With `-ErrorAction Stop`, the invocation terminates; earlier Monitor output may
already have reached a pipeline consumer. Check both metric completeness and
cost statuses before using the results.

**Never sum `CostDetail`, `CostMeter` and `CostComparison` costs together**: they overlap.
For total reported cost across selected accounts, use only `CostMeter` rows,
grouped by currency and charge type. Some meters are unrelated to Blob requests,
and unassigned/non-account subscription charges are outside this report.
Blank resource IDs are excluded with a warning; a missing resource-ID column
is a schema error.
PowerShell's default table display can round tiny decimal costs to `0.00`;
CSV/JSON retain the actual values. For display without that rounding, select
a calculated column such as
`@{Name='Cost'; Expression={$_.ActualCost.ToString('G29')}}`
after filtering to `CostMeter` rows.

## Operation mappings and billing limitations

The maps use Microsoft's **logged operation names** from
[Map each REST operation to a price](https://learn.microsoft.com/en-us/azure/storage/blobs/map-rest-apis-transaction-categories),
checked on **2026-10-14**, not API verb prefixes. The
[logged operations reference](https://learn.microsoft.com/en-us/rest/api/storageservices/storage-analytics-logged-operations-and-status-messages)
confirms the Blob and Data Lake naming conventions. The price-category mapping
is the authority where the older logged-operations reference omits newer APIs.

| Microsoft category | Output category | Examples |
| --- | --- | --- |
| Read | `Reads` | `GetBlob`, `QueryBlobContents`, `ReadFile`, `GetPathAccessControl` |
| Write | `Writes` | `PutBlock`, `CreateFilesystem`, `AppendFile`, `FlushFile` |
| Iterative Read | `IterativeReads` | `ListFilesystems`, `ListFilesystemDir`, `ListFilesystemFile` |
| Iterative Write | `IterativeWrites` | `RenamePathDir`, `RenamePathFile`, `SetPathAccessControlRecursive` |
| Other | `AllOtherOperations` | `GetBlobProperties` in GPv2, `LeaseFile` |
| List and create container | `ListAndCreateContainer` | `ListBlobs`, `ListContainers`, `CreateContainer`, `FindBlobsByTags` |
| Free | `Free` | `DeleteBlob` in GPv2, `DeleteFile`, `DeleteFilesystem` |
| Unknown or ambiguous | `Unmapped` | New APIs, `Unknown`, `SetBlobTier`, page APIs not covered by the cited table |

**List and create container is a separate documented category**, not an iterative
read. It is preserved as an additional summary instead of forcing it into one of
the five requested buckets. `Free` and `Unmapped` are also separate; neither
contributes to the paid `AllOtherOperations` category.

Supported mapping columns are Standard GPv2 (`StorageV2`/`Standard_*`), Premium
block blob (`BlockBlobStorage`/`Premium_*`), and Standard GPv1
(`Storage`/`Standard_*`). GPv1 has its own overrides: for example,
`GetBlobProperties` is Read, `AbortCopyBlob` is Write and `DeleteBlob` is Other.
Data Lake mappings apply only to the first two columns; unsupported GPv1 APIs
remain unmapped. The account's HNS flag is retained but is not used to guess
operation names.

For other configurations, such as legacy `BlobStorage` or Premium GPv2/page
blob accounts, the collector warns and marks all observed requests
`UnsupportedAccount`/`Unmapped`. The cited table does not provide an account
column for them. Even on a supported account, APIs absent from that table are
unmapped rather than inferred. These counts remain part of the reconciled total.

`SetBlobTier` is deliberately ambiguous: the same logged API is Read for tier-up,
Write for tier-down, and Other for batch tier changes. The metric's `Tier` alone
does not disclose the direction or batch context. It cannot justify a unique
classification.

Counts are **not billed transaction quantities**:

- Transactions includes successful and failed requests, including authentication
  failures; the collector retains all response types and user/system transactions.
  Microsoft's mapping notes that authentication failures are not billed. An
  operation's category does not prove that every request in that category was paid.
- [ADLS pricing](https://azure.microsoft.com/en-us/pricing/details/storage/data-lake/)
  states that each 4 MB read/written is charged as a transaction: its 6 MB example
  incurs two transactions for one operation. Request metrics lack the per-request
  size information required to reproduce that rounding. Aggregate ingress/egress
  cannot recover it.
- Iterative operations, client retries, batch requests, cross-account copies,
  protocol translations and other pricing rules can also differ from one charge
  per observed request. This collector does not infer billable equivalents.
- The account's current default tier is not the tier of every historical blob.
  Detail rows preserve the actual metric `Tier`; summaries span all tiers.
- Blob and DFS endpoints can use different pricing schedules even with HNS enabled.
  Choose calculator scope using the actual workload/endpoint, not just the HNS flag.

See [Plan and manage costs](https://learn.microsoft.com/en-us/azure/storage/common/storage-plan-manage-costs)
and [Estimate Blob Storage costs](https://learn.microsoft.com/en-us/azure/storage/blobs/blob-storage-estimate-costs)
for endpoint, block-size and billing context. No pricing calculations are performed
by this script.

## Query acceleration data scanned and returned

The [Blob monitoring reference](https://learn.microsoft.com/en-us/azure/storage/blobs/monitor-blob-storage-reference)
does not list query-acceleration scanned/returned bytes as platform metrics.
`QueryBlobContents` contributes observed Read requests, but not the two byte meters.
Neither total Ingress/Egress nor filtered `QueryBlobContents` traffic is substituted.
The resource log schema's `responseBodySize` describes response packets; it is not
a documented query-acceleration meter.

The [Query Blob Contents REST response](https://learn.microsoft.com/en-us/rest/api/storageservices/query-blob-contents#response-body)
provides an Avro stream with:

- `com.microsoft.azure.storage.queryBlobContents.progress.bytesScanned`: cumulative
  bytes scanned; progress records must not be summed as independent increments.
- `progress.totalBytes` and `end.totalBytes`: the total bytes **to be scanned**,
  not a field named bytes returned or a guarantee that an interrupted query scanned
  the entire input.
- `com.microsoft.azure.storage.queryBlobContents.resultData.data`: the actual
  returned result byte payload. There is no documented `bytesReturned` scalar.

Historical scanned/returned observations require the querying application to
**already have persisted** progress, result-payload byte counts, completion/error
status, request IDs, account IDs and timestamps. Logging returned content is
unnecessary; only record byte counts. Partial/failed queries and retries require
careful attribution. These observations are not asserted to reproduce billing.
This script cannot recover those streams retrospectively and does not enable
diagnostic settings, issue data-plane queries or add a custom telemetry importer.
Both byte fields stay null, including when no query requests were observed.

## Completeness, missing values and errors

The collector uses the
[Azure Monitor Metrics List API](https://learn.microsoft.com/en-us/rest/api/monitor/metrics/list)
through `Invoke-AzRestMethod` from Az.Accounts. REST allows `interval=FULL` (one
total per query window), and exposes explicit `top`; the default for filtered
queries is only 10. This avoids relying on a cmdlet's default top or flattening
away dimensions. Az.Monitor is not an additional prerequisite.

For each bounded chunk it requests Transactions **Total**, splitting all six
documented dimensions with `top=10000`, then requests an unsplit **Blob-service**
Total. It rejects duplicate dimension combinations, missing dimensions,
unexpected units/point shapes, metric-level errors and HTTP failures.
The sum of split totals must equal the unsplit total. Reaching the explicit
series cap fails even if totals match; the collector never claims success from
a capped result. This checks observed count completeness, not Azure's telemetry
delivery guarantees or the presence of every zero-valued series.

An absent/null Total is not synthesized as zero. If any split Total or the
unsplit Total is missing, every category summary for that chunk is null and
`UnverifiableMissingData`; a warning is emitted. Available detail counts remain
visible with that same completeness status. If both the split and unsplit
queries return an explicit `errorCode: Success` with empty timeseries (Azure
Monitor's no-traffic response, confirmed live on idle accounts), or the unsplit
query returns a zero Total, the summaries are observed zeros. An empty response
without an explicit `Success` stays unknown.
`Reconciled` does not promise that every minute had telemetry or that Azure
will never revise recent data.

Monthly rollups preserve these semantics. Any missing unsplit chunk Total makes
the month's `AccountTotal` null. Any incomplete chunk makes all monthly category
summaries null and marks every record in that month `UnverifiableMissingData`.
Detail groups with missing counts are null; other detail groups retain their
observed counts, but the month is still incomplete. Null counts are never skipped
to present a partial sum as a complete monthly total.

On an account/query failure, the function writes to the error stream, discards
all buffered rows for that account, emits one null-valued `Error` record, and
continues to other accounts. Use `-ErrorAction Stop` to fail the whole invocation
instead (the error record then cannot be emitted). Invalid inputs fail before
collection. Missing data produces warnings/statuses rather than account errors;
check completeness before aggregating even with `-ErrorAction Stop`.

For a reconciliation mismatch or series-cap failure, retry a completed older
window or reduce `-ChunkHours` to 1. If even an hourly query fails, collection is
explicitly blocked rather than returning truncated numbers. For HTTP 403 check
management-plane RBAC; for 429 retry later. The script creates no Azure resources,
so there is nothing to clean up or roll back.

## Offline verification

The repository has no pre-existing PowerShell test suite. Focused tests use the
locally available Pester 3.4.0 runner, mock only the Az boundaries, and call the
public function without credentials or network access:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
$test = Invoke-Pester -Script .\PowerShell\StorageMetrics\tests\Get-AzStorageTransactionMetric.Tests.ps1 -PassThru
if ($test.FailedCount) { throw "$($test.FailedCount) tests failed." }
```

Tests cover documented mappings, account-column differences, dimensions,
aggregation, missing versus zero, unavailable acceleration data, multiple
accounts/subscriptions, failures, chunk/month boundaries, partial-month coverage
and completeness checks.
Before relying on a production run, compare one completed window's
`AccountTotal` and detailed splits with Azure Monitor Metrics Explorer on the
same Blob service, aggregation, window and dimensions.

Cost tests use the same public function, mock Azure/report-download/delay
boundaries, and exercise CSV input, units, catalog exclusions, currencies,
refunds, missing counts/meters, scope/date filtering, output exports,
asynchronous multi-part downloads and bounded polling/failure handling:

```powershell
$test = Invoke-Pester -Script .\PowerShell\StorageMetrics\tests -PassThru
if ($test.FailedCount) { throw "$($test.FailedCount) tests failed." }
```

Capacity tests exercise the same public function with mocked hourly responses:
unequal chunk lengths, tier splits, HNS index, missing/zero/empty samples,
month boundaries, reconciliation, duplicate timestamps/series, failures,
multiple accounts, strict mode and CSV fields. Billing tests also cover daily
evidence, benefit/rate separation, per-100 units, verified non-operation quantities
and unknown meters/units. No tests require Azure credentials.
Workload baseline tests use the public collector to cover binary capacity units,
HNS index separation, request dimensions and billability, missing/zero quantities,
unknown tiers/units/meters, billing contexts and corrections, source failures,
month/account isolation, opt-in behavior and CSV/JSON output.

## Remaining pricing-model gaps

These extensions collect historical capacity and preserve richer billing
evidence; they do not implement independent price selection or redundancy scenarios.
Validate the current configuration against comparable billing before applying
ZRS, GRS, GZRS or RA-GRS prices. Keep reservations/negotiated rates separate,
and do not use chargeback dollars per GB or arbitrary SKU multipliers as prices.
Retrieval, replication, early deletion and endpoint history may still require
already-existing logs/inventory/application telemetry or reviewed supplements.
Billing-derived quantities are labeled as such, not independent Monitor evidence.

Archive data cannot remain unchanged under ZRS/GZRS. Secondary-read-dependent
workloads cannot retain their access pattern under non-RA targets. Check region,
kind/performance and architecture eligibility before ranking costs, and keep
migration, seeding and rehydration costs separate from recurring monthly run rate.

## Live validation

Run once against six Standard_LRS StorageV2 accounts (one subscription, 7 UTC days, 24h chunks): all accounts returned without errors and every chunk reconciled split vs. unsplit totals. Idle accounts returned explicit zeros. Counts were not compared with Portal Metrics Explorer.

Monthly output was subsequently checked live for the same six accounts and
seven-day window. Each monthly total/category matched the sum of the saved
daily records, and the October period was correctly marked as partial.
Monthly CSV/JSON artifacts were saved separately from the original daily CSV.
This was not a full-month live run or a Cost Management reconciliation.

The subsequent full September 2026 live check on four `mnsigs` accounts used
the new Cost Details API mode and returned ten account meters. Observed/billed
counts matched for `samnsigscontact` Reads (260), Writes (2), List/Create (2)
and `samnsigs001` Reads (82). `samnsigs001` AllOtherOperations had 92 observed
requests versus 2 billed operations; its metric details showed error responses.
Its 495 authorization-error list requests had no matching billed list meter.
Capacity, bandwidth and Defender charges were retained separately. No
query-acceleration meters were present.
The reported selected-account costs totaled `0.003529548 USD`, including the
non-operation meters. CSV-input comparisons matched the live API results.

The capacity extension was checked live for `samnsigs001` in September 2026.
It returned Hot/BlockBlob capacity with all 720 expected hourly samples and
reconciled split/unsplit averages: 9,736,770 bytes. The same run used the saved
September cost-details CSV and retained 54 daily evidence rows, classifying
capacity, operations and network meters while preserving rates and pricing context.
This checks one single-tier, non-HNS account; it is not validation of every
capacity configuration or an independently calculated cost baseline.

The subsequent workload-baseline run collected September capacity and transactions
for all four selected `mnsigs` accounts, using the saved actual-cost CSV.
For `samnsigs001`, the sampled estimate was 0.0090680737 GiBMonth versus
0.009360 billed GiBMonth, a -3.1189% quantity difference that remains unexplained.
`rgmnsigseventsaff2` had complete GPv1 samples labeled `Untiered` and an unlabeled
`General Block Blob` capacity meter. The GPv1-specific comparison reports
0.0448656622 sampled GiBMonth versus 0.044640 billed GiBMonth, a +0.5055%
difference; neither source is assigned to Hot. `sakioocs` and
`samnsigscontact` had incomplete capacity samples. All unresolved conditions
remain explicit instead of yielding a validated baseline. The normalized billing
rows preserved the original 0.003529548 USD selected-account cost and retained
unknown/Defender meters. These are quantity diagnostics, not price calculations.

Follow-up live queries on October 14 checked whether query boundaries caused
these differences:

| Evidence | Result |
| --- | --- |
| `samnsigs001`, independent full-month daily `BlobCapacity` query | All 30 daily averages were 9,736,770 bytes, matching the hourly average. The discrepancy is not explained by daily chunking or unequal averaging. |
| Capacity billing date coverage | Both billed-capacity accounts have 30 dated Usage rows spanning September 1-30. Daily quantities are constant: 0.000312 and 0.001488 GB/Month respectively. Date coverage alone does not establish billing accuracy or completeness. |
| `sakioocs`, full-month hourly split and unsplit queries | Both still lack numeric samples at September 15 14:00 UTC and September 30 14:00 UTC. Available samples are zero, but missing hours are not inferred to be zero. |
| `samnsigscontact`, full-month hourly split and unsplit queries | Both still lack a numeric sample at September 25 20:00 UTC. A complete monthly capacity estimate cannot be reconstructed from these metrics. |

The remaining capacity differences cannot be attributed to a specific billing
rule from this evidence. No correction factor is applied. Resolving them requires
the billing meter's underlying capacity measurement/precision semantics and
historical configuration evidence; missing Monitor hours require an independent
historical source or a different fully covered baseline month. A current blob
listing would not reconstruct September usage. The GPv1 accounts also require
an explicit account-type/pricing assumption when evaluating modern redundancy
options; a redundancy-only rate change is not sufficient.

A subsequent current-footprint run on October 14 returned reconciled Blob
capacity samples for all four accounts at 20:00 UTC (about 1.3 hours old):
48,174,138 bytes for `rgmnsigseventsaff2`, 0 bytes for `sakioocs`, 9,736,770
bytes for `samnsigs001`, and 282,574 bytes for `samnsigscontact`. The accompanying
seven-day October transaction window returned 67 observed requests for
`samnsigs001` and zero for the other three accounts. These are current samples
and recent observed counts, not extrapolated monthly costs.
