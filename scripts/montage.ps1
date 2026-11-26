param([Parameter(Mandatory)][string]$Site, [string]$Filter = '*', [int]$Cell = 420, [int]$Cols = 3)
Add-Type -AssemblyName System.Drawing
$src = Join-Path "C:\Users\bcokgul\OneDrive - Tesla\Desktop\SCA" $Site
$files = @(Get-ChildItem $src -File -Filter $Filter | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' } | Sort-Object Name)
if (-not $files) { "NO IMAGES"; exit 1 }
$rows = [Math]::Ceiling($files.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap -ArgumentList ($Cell * [Math]::Min($Cols, $files.Count)), ($Cell * $rows)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::White)
$font = New-Object System.Drawing.Font -ArgumentList 'Arial', 14, ([System.Drawing.FontStyle]::Bold)
for ($i = 0; $i -lt $files.Count; $i++) {
  $img = [System.Drawing.Image]::FromFile($files[$i].FullName)
  foreach ($p in $img.PropertyItems) { if ($p.Id -eq 0x0112) { switch ($p.Value[0]) { 3 { $img.RotateFlip('Rotate180FlipNone') } 6 { $img.RotateFlip('Rotate90FlipNone') } 8 { $img.RotateFlip('Rotate270FlipNone') } } } }
  $r = [Math]::Min(($Cell - 6) / $img.Width, ($Cell - 6) / $img.Height)
  $w = [int]($img.Width * $r); $h = [int]($img.Height * $r)
  $x = ($i % $Cols) * $Cell + [int](($Cell - $w) / 2); $y = [Math]::Floor($i / $Cols) * $Cell + [int](($Cell - $h) / 2)
  $g.DrawImage($img, $x, $y, $w, $h)
  $g.DrawString([string]($i + 1), $font, [System.Drawing.Brushes]::Yellow, ($i % $Cols) * $Cell + 6, [Math]::Floor($i / $Cols) * $Cell + 4)
  $img.Dispose()
}
$out = Join-Path $env:TEMP ("sca_preview\montage_{0}.jpg" -f ($Site -replace '[^\w-]', '_'))
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
$sheet.Save($out, [System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $sheet.Dispose()
$out
