param(
  [Parameter(Mandatory)][string]$Site,
  [Parameter(Mandatory)][string]$Name,
  [Parameter(Mandatory)][int]$Count,
  [Parameter(Mandatory)][datetime]$Since,
  [string]$AC = '',
  [int]$TimeoutSec = 180
)
$dl = "$env:USERPROFILE\Downloads"
$dest = Join-Path "C:\Users\bcokgul\OneDrive - Tesla\Desktop\SCA" $Site
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$deadline = (Get-Date).AddSeconds($TimeoutSec)
do {
  $files = @(Get-ChildItem $dl -File | Where-Object { $_.CreationTime -ge $Since -and $_.Extension -notin '.crdownload', '.part' })
  $partial = @(Get-ChildItem $dl -File | Where-Object { $_.CreationTime -ge $Since -and $_.Extension -in '.crdownload', '.part' })
  if ($files.Count -ge $Count -and $partial.Count -eq 0) { break }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

$sizes = @{}; foreach ($f in $files) { $sizes[$f.FullName] = $f.Length }
Start-Sleep -Seconds 3
$files = @(Get-ChildItem $dl -File | Where-Object { $_.CreationTime -ge $Since -and $_.Extension -notin '.crdownload', '.part' } | Sort-Object CreationTime)
if ($files.Count -lt $Count) { "ONLY {0}/{1} FILES" -f $files.Count, $Count }

$i = 1
foreach ($f in $files) {
  $b = [System.IO.File]::ReadAllBytes($f.FullName)
  $ext = '.bin'
  if ($b[0] -eq 0xFF -and $b[1] -eq 0xD8) { $ext = '.jpg' }
  elseif ($b[0] -eq 0x89 -and $b[1] -eq 0x50) { $ext = '.png' }
  elseif ([System.Text.Encoding]::ASCII.GetString($b, 4, 4) -eq 'ftyp') { $ext = '.heic' }
  elseif ([System.Text.Encoding]::ASCII.GetString($b, 0, 4) -eq '%PDF') { $ext = '.pdf' }
  $base = "{0}_{1}" -f $Name, $i
  if ($AC) { $base = "${base}_$AC" }
  $target = Join-Path $dest ($base + $ext)
  $j = 2
  while (Test-Path $target) { $target = Join-Path $dest ("{0}_v{1}{2}" -f $base, $j, $ext); $j++ }
  Move-Item $f.FullName $target
  "{0} <- {1} ({2} KB)" -f $target, $f.Name, [int]($b.Length / 1KB)
  $i++
}
