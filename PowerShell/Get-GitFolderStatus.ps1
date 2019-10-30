<#       
Copyright (c) Tim Sullivan. All rights reserved.
Licensed under the MIT license. See LICENSE file in the project root for full license information.
#>
[cmdletbinding()]
param(
    $path = (Get-Location).path
)

Get-ChildItem -Directory -Path $path |
Select-Object -Expand FullName | 
ForEach-Object {
  Push-Location $_
  if ( (Get-ChildItem -Hidden -Directory | select -ExpandProperty name) -contains '.git') {
    Write-Verbose "$_ is a git repository"
    Write-Host "Checking $_"
    git status -s -b
  }
  Pop-Location
}
