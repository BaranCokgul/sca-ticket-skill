param(
  [Parameter(Mandatory)][string]$Site,
  [Parameter(Mandatory)][string]$Name,
  [string]$AC = ''
)
$dl = "$env:USERPROFILE\Downloads"
$root = "C:\Users\bcokgul\OneDrive - Tesla\Desktop\SCA"
$dest = Join-Path $root $Site
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$f = $null
for ($i = 0; $i -lt 30 -and -not $f; $i++) {
  $f = Get-ChildItem $dl -File |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-60) -and $_.Extension -notin '.crdownload', '.part' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { Start-Sleep -Seconds 1 }
}
if (-not $f) { "NO FILE"; exit 1 }
$prev = -1
for ($i = 0; $i -lt 30; $i++) {
  $f.Refresh()
  if ($f.Length -gt 0 -and $f.Length -eq $prev) { break }
  $prev = $f.Length
  Start-Sleep -Seconds 2
}

$b = [System.IO.File]::ReadAllBytes($f.FullName)
$ext = '.bin'
if ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) { $ext = '.jpg' }
elseif ($b[0] -eq 0x89 -and $b[1] -eq 0x50) { $ext = '.png' }
elseif ([System.Text.Encoding]::ASCII.GetString($b, 4, 4) -eq 'ftyp') { $ext = '.heic' }
elseif ([System.Text.Encoding]::ASCII.GetString($b, 0, 4) -eq '%PDF') { $ext = '.pdf' }

$base = if ($AC) { "${Name}_$AC" } else { $Name }
$target = Join-Path $dest ($base + $ext)
$i = 2
while (Test-Path $target) { $target = Join-Path $dest ("{0}_{1}{2}" -f $base, $i, $ext); $i++ }

Move-Item $f.FullName $target
"{0} <- {1} ({2} KB) {3}" -f $target, $f.Name, [int]($b.Length / 1KB), (Get-FileHash $target -Algorithm MD5).Hash.Substring(0, 8)
