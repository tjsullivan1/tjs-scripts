[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName
)

# Get the five most recent billing periods, but make sure they are in the past (-lt (get-date))
$billing_periods = Get-AzBillingPeriod | sort-object -Top 5 | Where-Object BillingPeriodEndDate -lt (get-date) | Select-Object -ExpandProperty name
$monthly_costs = @()

foreach ($period in $billing_periods) 
{
    Write-Verbose $period
    $summed_cost = Get-AzConsumptionUsageDetail -ResourceGroup $ResourceGroupName -BillingPeriodName $period | Measure-Object PretaxCost -Sum | Select-Object -ExpandProperty Sum

    # We'll only take action if summed cost has a value. (Periods with no usage are $null, not 0)
    if ($summed_cost) 
    {
        Write-Verbose $summed_cost
        $monthly_costs += $summed_cost
    }       
}

$monthly_costs | Sort-Object -Descending | Select-Object -First 1