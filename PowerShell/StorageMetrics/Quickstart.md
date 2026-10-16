# Storage metrics quickstart

Run these commands in **PowerShell 7+ from the repository root**. Replace the
placeholder tenant, subscription, resource group and account values before
running them. This guide collects Blob/ADLS metrics, not Files, Queue or Table
metrics, and does not change storage account settings.

## 1. Set up PowerShell and account access

Install [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
if needed, open `pwsh`, then install the authentication module:

```powershell
Install-Module Az.Accounts -Scope CurrentUser
Import-Module Az.Accounts
Connect-AzAccount -Tenant '<tenant-id>' -Subscription '<subscription-id>'
Get-AzContext -ListAvailable

. .\PowerShell\StorageMetrics\Get-AzStorageTransactionMetric.ps1
. .\PowerShell\StorageMetrics\Get-AzStorageRedundancyCost.ps1

$accountId = '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<account-name>'
```

Copy the account's full **Resource ID** from the Azure portal's Properties page.
Use the account ID, not its URL or a `/blobServices/default` child ID.
The scripts do not discover accounts or sign in for you.

Have exactly **one saved Az context per subscription** you will query.
Inspect `Get-AzContext -ListAvailable`; missing or duplicate contexts fail
explicitly. If duplicates exist, use `Remove-AzContext -Name '<unwanted-context-name>'`
to remove only the unwanted saved context, then inspect the list again.
The collector selects the matching context for each request without switching
your active context.

For metrics, the signed-in identity needs **Monitoring Reader** or **Reader**
on the account, resource group or subscription (storage-account read and Blob
service metrics read). You do not need account keys, Storage Blob Data Reader
or diagnostic settings. Billing API access additionally needs cost-data read
permissions, usually **Cost Management Reader** at subscription scope, plus any
required billing visibility settings. Metrics access alone is not billing access.

## 2. Get metrics for one account

Calculate the last completed UTC calendar month dynamically:

```powershell
$now = [datetimeoffset]::UtcNow
$monthEnd = [datetimeoffset]::new(
    $now.Year, $now.Month, 1, 0, 0, 0, [timespan]::Zero)
$monthStart = $monthEnd.AddMonths(-1)

$metrics = @(Get-AzStorageTransactionMetric -ResourceId $accountId `
    -StartTime $monthStart -EndTime $monthEnd `
    -IncludeDetail -IncludeCurrentCapacity -ErrorAction Stop)

# One monthly transaction total per account.
$metrics | Where-Object RecordType -eq 'AccountTotal' |
    Select-Object StorageAccountName, Month, RequestCount, CompletenessStatus

# Monthly operation categories and the current capacity snapshot.
$metrics | Where-Object RecordType -eq 'Summary' |
    Select-Object Month, Category, RequestCount, CompletenessStatus
$metrics | Where-Object RecordType -eq 'CurrentCapacity' |
    Select-Object Tier, BlobType, CurrentUsedGiB, CapacitySampleTimeUtc,
        CapacitySampleAgeHours, CapacityStatus
```

`-IncludeDetail` retains API/tier/response dimensions for investigation and
pricing. Transactions are observed requests, **not guaranteed billable operations**.
`-IncludeCurrentCapacity` independently selects a recent reconciled capacity
snapshot; it is not last month's average capacity.

Start is inclusive and end is exclusive. Metrics have a 93-day retention window.
The default output groups transactions by UTC calendar month. Unless
`-AllowRecentData` is supplied, the exclusive end must be at least three hours
before now so Azure Monitor has time to ingest metrics; this switch does not
allow future end times.

The default `-ChunkHours` is 24; set it from 1 through 744 to choose a larger
maximum window (up to a 31-day UTC month). A mismatch between split and unsplit
totals or a `top=10000` series cap causes automatic halving down to one hour,
then a fail-closed error if it still cannot be verified. `-SummaryPeriod Chunk`
returns successful transaction windows, with their actual durations in
`QueryWindowHours`. Capacity chunk records report the largest successful hourly
query window used in their aggregate.

Transient ARM GET responses (429, 500, 502, 503, 504) are retried four times by
default. `-MaxRetry` changes that number; `Retry-After` is honored when present,
otherwise exponential backoff with jitter is used. Azure PowerShell may also
retry 429 responses internally; `AZURE_PS_HTTP_MAX_RETRIES_FOR_429` controls
that separate Az retry layer and can extend the total wait.

## 3. Get actual billed costs for one account

Use the completed-month variables above. Choose **one** billing source:

```powershell
# Cost Details report API, when supported by your billing offer.
$billed = @(Get-AzStorageTransactionMetric -ResourceId $accountId `
    -StartTime $monthStart -EndTime $monthEnd `
    -IncludeCostComparison -ErrorAction Stop)
```

For unsupported offers or an existing usage-details download/export, supply
complete actual-cost CSV files instead:

```powershell
# Include every partition covering the account and requested month.
$costFiles = @('.\cost-part1.csv', '.\cost-part2.csv')
$billed = @(Get-AzStorageTransactionMetric -ResourceId $accountId `
    -StartTime $monthStart -EndTime $monthEnd `
    -CostDetailsCsv $costFiles -ErrorAction Stop)
```

EA/MCA offers generally support the report API. MOSP/pay-as-you-go and Visual
Studio offers can require CSV; the script does not silently choose another API.
CSV avoids billing API calls, **not** the collector's Azure Monitor calls.
Reading an export from storage requires separate data-plane access; download
the files locally before using the CSV example.

Sum only `CostMeter` rows, keeping currencies and charge types separate:

```powershell
$meters = @($billed | Where-Object RecordType -eq 'CostMeter')
if (-not $meters.Count -or @($meters | Where-Object {
    $null -eq $_.ActualCost -or [string]::IsNullOrWhiteSpace($_.Currency)
}).Count) {
    throw 'No usable billing costs; check coverage and missing values.'
}
$meters | Group-Object ResourceId, Month, Currency, ChargeType |
    ForEach-Object {
        [pscustomobject]@{
            StorageAccountName = $_.Group[0].StorageAccountName
            Month = $_.Group[0].Month
            Currency = $_.Group[0].Currency
            ChargeType = $_.Group[0].ChargeType
            ReportedCost = ($_.Group | Measure-Object ActualCost -Sum).Sum
        }
    }
```

These are reported costs for matched account meters, including non-request
meters, not a complete subscription invoice. Unassigned charges and charges
attributed to other resources are outside the report. CSV coverage is unverified;
reading all API report partitions does not prove billing is final.
Do not combine currencies or add `CostComparison`/`CostDetail` costs to
`CostMeter` costs: those record types overlap. Add `-IncludeCostDetail` to either
collection example only if you need daily billing evidence.

## 4. Estimate public-rate redundancy costs for one account

This is **planning**, not the actual billed-cost workflow above. Collect a
representative recent seven-day request window ending at a completed UTC hour,
plus current capacity, then model the current calendar month:

```powershell
$recentEnd = [datetimeoffset]::UtcNow
$recentEnd = $recentEnd.AddTicks(-($recentEnd.Ticks % [timespan]::TicksPerHour))
$recentEnd = $recentEnd.AddHours(-3)
$recentStart = $recentEnd.AddDays(-7)
$modelMonth = [datetimeoffset]::UtcNow.ToString('yyyy-MM')

$recent = @(Get-AzStorageTransactionMetric -ResourceId $accountId `
    -StartTime $recentStart -EndTime $recentEnd `
    -IncludeDetail -IncludeCurrentCapacity -ErrorAction Stop)
$estimate = @(Get-AzStorageRedundancyCost -Records $recent `
    -ModelMonth $modelMonth -ErrorAction Stop)

$estimate | Where-Object RecordType -eq 'Scenario' |
    Select-Object StorageAccountName, Redundancy, Currency, PricedSubtotal,
        IsCurrentConfiguration, DeltaFromCurrent, DeltaFromCurrentReason,
        PricingMode, Status, UnpricedComponents, ExcludedCharges
```

The pricing command fetches current public USD retail rates without billing
credentials. It holds snapshot capacity constant for the modeled month and
scales observed requests by modeled-month hours / observed-window hours.
You must decide whether that recent workload represents normal activity.
Month boundaries can split the collected records; keep all records in `$recent`.
Pass typed objects (as above) or imported JSON, **not CSV strings**, to pricing.

The default returns six scenarios: `LRS`, `ZRS`, `GRS`, `GZRS`, `RA-GRS` and
`RA-GZRS`. Select a subset with `-Scenario LRS, RA-GZRS`. `IsCurrentConfiguration`
matches the redundancy suffix in the current account `SkuName`; `DeltaFromCurrent`
is target minus current priced subtotal, and remains null with a reason if either
subtotal is missing or the scenarios price different component sets.

Geo-replication transfer is excluded by default. To add a caller-provided monthly
assumption (GiB; never inferred from request counts), pass
`-EstimateGeoReplicationFromWriteBytes 1200`. A matching `GeoReplicationTransfer`
line is added only for GRS/GZRS/RA-GRS/RA-GZRS scenarios. The estimator converts
GiB to decimal GB to match the live Retail Prices API meter; if that exact meter
is unavailable, the line stays `PriceUnavailable`.

`PricedSubtotal` includes only priced components, not a complete monthly bill.
Retrieval, network bandwidth, early deletion, feature charges, migration costs,
discounts, reservations and taxes are excluded. Geo-replication transfer remains
excluded unless the explicit assumption above is supplied. Unsupported
premium/page-blob inputs, ambiguous tiers and unknown APIs remain unpriced; some
scenarios can be ineligible. Inspect the status and exclusions, not just the
subtotal. Do not add `Estimate` line costs to `Scenario` subtotals.

For an **ADLS Gen2 account with HNS enabled**, explicitly choose the workload's
endpoint schedule. Neither command changes the account:

```powershell
# DFS endpoint (dfs.core.windows.net), for example ABFS analytics workloads.
$adlsEstimate = @(Get-AzStorageRedundancyCost -Records $recent `
    -ModelMonth $modelMonth -PricingMode AdlsGen2 -ErrorAction Stop)

# Alternative: Blob endpoint on HNS, including NFS/SFTP workloads.
$blobHnsEstimate = @(Get-AzStorageRedundancyCost -Records $recent `
    -ModelMonth $modelMonth -PricingMode BlobHns -ErrorAction Stop)
```

The default `-PricingMode BlobFlat` still leaves HNS accounts unpriced. Both HNS
modes require a known HNS-enabled Standard GPv2 account. Choose one schedule for
the supplied workload; the HNS flag does not identify the endpoint. These are
alternative estimates, **not additive**. Mixed-endpoint requests need separate,
reconciled inputs; adding both scenario subtotals would double-count capacity.

Both HNS modes accept Azure Monitor's documented `BlobType = Azure Data Lake
Storage` as data capacity, as well as BlockBlob/AppendBlob. Same-tier splits
share one graduated capacity calculation. Public HNS data-storage rates are
available; the ADLS dimension does not by itself mean capacity is unpriced.
PageBlob and unknown types remain unsupported.

`Scenario.Status = PartialEstimate` is intentional even when every supported
line has a price. Check the actual capacity lines and omitted components:

```powershell
$adlsEstimate | Where-Object Component -eq 'Capacity' |
    Select-Object Redundancy, Tier, Quantity, QuantityUnit, EstimatedCost, Status
$adlsEstimate | Where-Object RecordType -eq 'Scenario' |
    Select-Object Redundancy, PricedSubtotal, UnpricedComponents
```

An unpriced capacity line has null quantity/cost and contributes nothing to the
subtotal. A small subtotal can therefore reflect priced requests/index only,
not the cost of storing the account's data. Inspect `UnpricedComponents` and
warnings rather than treating `PartialEstimate` as proof that capacity is absent.

To reprice an existing collector JSON export without collecting metrics again:

```powershell
. .\PowerShell\StorageMetrics\Get-AzStorageRedundancyCost.ps1
$jsonOptions = @{}
# PowerShell 7.5+ can preserve timestamp strings; older PS7 uses its default parser.
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
    $jsonOptions.DateKind = 'String'
}
$saved = @(Get-Content .\storage-metrics.json -Raw | ConvertFrom-Json @jsonOptions)
$adlsEstimate = @(Get-AzStorageRedundancyCost -Records $saved `
    -ModelMonth $modelMonth -PricingMode AdlsGen2 -ErrorAction Stop)
```

The export must contain `CurrentCapacity` and reconciled `AccountTotal`/`Detail`
records from `-IncludeCurrentCapacity -IncludeDetail`. Use `BlobHns` instead when
that is the workload's endpoint schedule. Repricing fetches public retail rates
only; it does not refresh the saved capacity snapshot or call private Azure or
billing APIs. Keep the original snapshot date in mind. CSV is not a typed input.

Both HNS modes add a separate Hot index-capacity line from `CurrentIndexCapacity`,
once per account/scenario, without adding it to Blob data capacity. Missing index
samples or rates stay unpriced, not zero. DFS read/write costs approximate requests:
ADLS bills transfers in 4-MiB units and recursive/iterative operations can differ
from request counts. The estimator does not invent size or fan-out multipliers.
Iterative writes use the catalog's **per-100** rate, not per-10,000.
Every output row includes `PricingMode` and `BillabilityAssumption`.
SFTP hourly charges and other feature charges remain excluded.

For a GPv1 projection, `-LegacyTargetTier Hot` explicitly assumes migration to
GPv2 Hot. `-AssumeFlatNamespace` explicitly assumes flat namespace only when ARM
omits the HNS flag; it does not override known HNS accounts. Use either switch
only when you can justify and record the assumption. See the
[detailed pricing guide](StorageTransactionMetrics.md#public-retail-redundancy-planning-estimates)
for supported configurations and limitations.

## 5. Run across multiple accounts and subscriptions

For accounts in one subscription, reuse its saved context. For another
subscription (including another tenant), sign in separately first:

```powershell
Connect-AzAccount -Tenant '<second-tenant-id>' -Subscription '<second-subscription-id>'
Get-AzContext -ListAvailable

$accountIds = @(
    '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<first-account>'
    '/subscriptions/<second-subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<second-account>'
)

$allMetrics = @($accountIds | Get-AzStorageTransactionMetric `
    -StartTime $monthStart -EndTime $monthEnd `
    -IncludeDetail -IncludeCurrentCapacity -ErrorAction Stop)

$allBilled = @($accountIds | Get-AzStorageTransactionMetric `
    -StartTime $monthStart -EndTime $monthEnd `
    -IncludeCostComparison -ErrorAction Stop)

$allRecent = @($accountIds | Get-AzStorageTransactionMetric `
    -StartTime $recentStart -EndTime $recentEnd `
    -IncludeDetail -IncludeCurrentCapacity -ErrorAction Stop)
$allEstimates = @(Get-AzStorageRedundancyCost -Records $allRecent `
    -ModelMonth $modelMonth -ErrorAction Stop)
```

Check for exactly one saved context per supplied subscription before collection.
Every account needs metrics access; each subscription needs billing access for
the API example. For CSV billing, replace `-IncludeCostComparison` with
`-CostDetailsCsv $costFiles`, supplying all relevant account/month partitions
across subscriptions. Group costs by account/month/currency/charge type as above.
Account IDs are explicit; duplicate IDs are collected once.

## Export and check results

```powershell
$allMetrics | Export-Csv -LiteralPath .\storage-metrics.csv -NoTypeInformation
ConvertTo-Json -InputObject $allMetrics -Depth 6 |
    Set-Content -LiteralPath .\storage-metrics.json -Encoding utf8
$allBilled | Export-Csv -LiteralPath .\storage-billed-costs.csv -NoTypeInformation
$allEstimates | Export-Csv -LiteralPath .\storage-estimates.csv -NoTypeInformation
ConvertTo-Json -InputObject $allEstimates -Depth 6 |
    Set-Content -LiteralPath .\storage-estimates.json -Encoding utf8
```

For a single account, export `$metrics`, `$billed` or `$estimate` instead.
CSV represents null as empty cells; JSON preserves null. Keep exports outside
version control if they contain private account or billing data.

The examples use `-ErrorAction Stop` so collection failures stop the command.
If you deliberately continue after errors, inspect `Error`, `CapacityError`,
`CurrentCapacityError` and `CostError` rows and their messages. A failure can leave
earlier pipeline output, so do not treat partial results as a successful run.
Warnings, missing-data and completeness statuses still need review even when
the command succeeds. **Null means unavailable, not zero.**

Always filter a record type before aggregating: transaction `AccountTotal`,
`Summary` and `Detail` overlap, as do `CurrentCapacity` and
`CurrentCapacityAccountTotal`. Snapshot capacity is not historical capacity.
The [detailed guide](StorageTransactionMetrics.md) covers output fields,
advanced capacity/workload modes, billing mappings and troubleshooting.
