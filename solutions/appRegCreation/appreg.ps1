[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $UserInputtedName,

    [Parameter(Mandatory=$true)]
    [string]
    $Username,

    [Parameter()]
    [string]
    $BusinessUnit
)

# Get seconds since epoch
$SecondsSinceEpoch = Get-Date -uFormat "%s"

$standardName = "appreg-$SecondsSinceEpoch-$userInputtedName"

write-debug "Standard name: $standardName"

# Create an azure ad application reistration using the user inputted name and add a tag for the creator's name. Also add a tag for date created.
$AppReg = New-MgApplication -DisplayName $standardName 

Write-Debug $AppReg

$updateParams = @{
    tags = @(
        "Creator: $($username)"
        "DateCreated: $(Get-Date)" 
        "Business Unit: $($businessUnit)"
    )
    serviceManagementReference = "For more information, please see XYZ page in wiki"
}

Update-MgApplication -applicationId $AppReg.Id -BodyParameter $updateParams
