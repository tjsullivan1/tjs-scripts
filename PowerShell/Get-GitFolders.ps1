[cmdletbinding()]
param(
    $path = (Get-Location).path
)

Get-ChildItem -Directory -Path $path |
Select-Object -Expand FullName | 
ForEach-Object {
  Push-Location $_
  if (Get-ChildItem -Hidden -Directory) {
    Write-Verbose "$_ is a git repository"
  }
  Pop-Location
}
