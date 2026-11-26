param([Parameter(Mandatory)][string]$Site, [int]$Max = 1000)
Add-Type -AssemblyName System.Drawing
$src = Join-Path "C:\Users\bcokgul\OneDrive - Tesla\Desktop\SCA" $Site
$out = Join-Path $env:TEMP "sca_preview\$Site"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Get-ChildItem $src -File | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' } | ForEach-Object {
  $img = [System.Drawing.Image]::FromFile($_.FullName)
  foreach ($p in $img.PropertyItems) { if ($p.Id -eq 0x0112) { switch ($p.Value[0]) { 3 { $img.RotateFlip('Rotate180FlipNone') } 6 { $img.RotateFlip('Rotate90FlipNone') } 8 { $img.RotateFlip('Rotate270FlipNone') } } } }
  $r = [Math]::Min(1.0, $Max / [Math]::Max($img.Width, $img.Height))
  $w = [int]($img.Width * $r); $h = [int]($img.Height * $r)
  $bmp = New-Object System.Drawing.Bitmap -ArgumentList $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($img, 0, 0, $w, $h)
  $dst = Join-Path $out $_.Name
  $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Jpeg)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
  $dst
}
