[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName
)

$billing_periods = Get-AzBillingPeriod | sort-object -Top 5 | Select-Object name

foreach ($period in $billing_periods) {
    Get-AzConsumptionUsageDetail -ResourceGroup $ResourceGroupName -BillingPeriodName $period | Measure-Object PretaxCost -Sum
}
    