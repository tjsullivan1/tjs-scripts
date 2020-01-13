[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName
)

$billing_periods = Get-AzBillingPeriod | sort-object -Top 5 | Where-Object BillingPeriodEndDate -lt (get-date) | Select-Object -ExpandProperty name

foreach ($period in $billing_periods) 
{
    Write-Verbose $period
    $summed_cost = Get-AzConsumptionUsageDetail -ResourceGroup $ResourceGroupName -BillingPeriodName $period | Measure-Object PretaxCost -Sum | Select-Object -ExpandProperty Sum
    if ($summed_cost) 
    {
        Write-Verbose $summed_cost
    }       
}
    