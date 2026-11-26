param([string]$Message = "SCA session update")
Set-Location (Split-Path $PSScriptRoot -Parent)
git add -A
git -c user.name="Baran Cokgul" -c user.email="bcokgul@tesla.com" commit -q -m $Message 2>&1 | Out-Null
git push -q 2>&1 | Out-Null
git log --oneline -1
