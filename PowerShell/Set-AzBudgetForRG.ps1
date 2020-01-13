[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName
)

$billing_periods = Get-AzBillingPeriod | sort-object -Top 5 | Select-Object -ExpandProperty name
Write-Debug $billing_periods

foreach ($period in $billing_periods) {
    Write-Debug $period
    $summed_cost = Get-AzConsumptionUsageDetail -ResourceGroup $ResourceGroupName -BillingPeriodName $period | Measure-Object PretaxCost -Sum | Select-Object -ExpandProperty Sum
    Write-Debug $summed_cost
}
    