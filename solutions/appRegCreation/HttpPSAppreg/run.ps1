using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

### HTTP Parameters ###

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}

$alias = $Request.Query.Alias
if (-not $alias) {
    $alias = $Request.Body.Alias
}

$businessUnit = $Request.Query.BusinessUnit
if (-not $businessUnit) {
    $businessUnit = $Request.Body.BusinessUnit
}
### Validate User is real ###
$domain = "sullivanenterprises.org"
$upn = "$alias@$domain"

$filter = "startsWith(UserPrincipalName, '$upn')"
$user = get-mguser -Filter $filter

if ($user) {
    write-debug "User: $user"
} else {
    $body =  "User $upn does not exist"

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = $body
    })

    throw $body
}

### Create Azure AD Application Registration ###

# Get seconds since epoch
$SecondsSinceEpoch = Get-Date -uFormat "%s"

$standardName = "appreg-$SecondsSinceEpoch-$name"

write-debug "Standard name: $standardName"

# Create an azure ad application reistration using the user inputted name and add a tag for the creator's name. Also add a tag for date created.
$AppReg = New-MgApplication -DisplayName $standardName 

Write-Debug $AppReg

$updateParams = @{
    tags = @(
        "Creator: $($alias)"
        "DateCreated: $(Get-Date)" 
        "Business Unit: $($businessUnit)"
    )
    serviceManagementReference = "For more information, please see XYZ page in wiki"
}

Update-MgApplication -applicationId $AppReg.Id -BodyParameter $updateParams

### HTTP Response ###
$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

if ($name) {
    $body = "Hello, $name. This HTTP triggered function executed successfully."
}


# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
