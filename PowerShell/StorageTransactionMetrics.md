# Storage transaction metrics

[`Get-AzStorageTransactionMetric.ps1`](Get-AzStorageTransactionMetric.ps1) collects
Azure Monitor **observed request counts** across explicitly selected storage
accounts. It returns flat `PSCustomObject` records for pipelines, CSV, JSON and
downstream scripts. It does not calculate prices or use Cost Management.
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
. .\PowerShell\Get-AzStorageTransactionMetric.ps1
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
| `RecordType` | `Summary`, `Detail`, `AccountTotal`, or `Error` |
| `SubscriptionId`, `ResourceGroupName`, `StorageAccountName`, `ResourceId` | Explicit account identity |
| `MetricResourceId` | Blob service queried |
| `Location`, `AccountKind`, `SkuName`, `IsHnsEnabled`, `AccountDefaultAccessTier` | Current account configuration; SKU includes redundancy |
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
    $_.RecordType -eq 'Error' -or $_.CompletenessStatus -ne 'Reconciled'
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

## Cross-checking Cost Management

This collector remains Azure Monitor-only. A cost comparison needs a separate
source of **billed usage quantities**, not just the currency totals in Cost
Analysis. The smallest first check is a downloaded usage-details CSV for one
completed month and the same account IDs, plus this script's monthly results
with `-IncludeDetail`.

The data access route depends on the billing offer:

- For Visual Studio or MOSP/pay-as-you-go subscriptions, Microsoft recommends
  [Exports or the Consumption Usage Details API](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/get-usage-details-legacy-customer).
  The newer Cost Details report API does not currently support those offers.
  A portal usage-details download is also suitable for a one-off comparison;
  an existing export avoids creating new resources.
- For EA/MCA, the [Cost Details report API](https://learn.microsoft.com/en-us/azure/cost-management-billing/automate/get-small-usage-datasets-on-demand)
  generates an asynchronous downloadable report. Automation must poll with
  `Retry-After` and read every report partition. Exports are another option.

The identity needs [cost-data read access](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/assign-access-acm-data),
typically Cost Management Reader at subscription scope, with any required
EA/MCA billing visibility settings enabled. Azure Monitor permissions alone
do not establish this access. Reading an export from Blob Storage additionally
requires data-plane read access to its destination. Creating a scheduled export
requires export-management and destination-storage permissions; a CSV importer
does not.

A comparison would:

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
$test = Invoke-Pester -Script .\PowerShell\tests\Get-AzStorageTransactionMetric.Tests.ps1 -PassThru
if ($test.FailedCount) { throw "$($test.FailedCount) tests failed." }
```

Tests cover documented mappings, account-column differences, dimensions,
aggregation, missing versus zero, unavailable acceleration data, multiple
accounts/subscriptions, failures, chunk/month boundaries, partial-month coverage
and completeness checks.
Before relying on a production run, compare one completed window's
`AccountTotal` and detailed splits with Azure Monitor Metrics Explorer on the
same Blob service, aggregation, window and dimensions.

## Live validation

Run once against six Standard_LRS StorageV2 accounts (one subscription, 7 UTC days, 24h chunks): all accounts returned without errors and every chunk reconciled split vs. unsplit totals. Idle accounts returned explicit zeros. Counts were not compared with Portal Metrics Explorer.

Monthly output was subsequently checked live for the same six accounts and
seven-day window. Each monthly total/category matched the sum of the saved
daily records, and the October period was correctly marked as partial.
Monthly CSV/JSON artifacts were saved separately from the original daily CSV.
This was not a full-month live run or a Cost Management reconciliation.
