param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Url, [string]$ContentType = 'image/jpeg')
$size = (Get-Item -LiteralPath $Path).Length
& curl.exe -s -o NUL -w "%{http_code}" -X PUT -H "Content-Type: $ContentType" -H "Content-Range: bytes 0-$($size-1)/$size" --data-binary "@$Path" $Url
