$skill = Split-Path $PSScriptRoot -Parent
$lastFile = Join-Path $skill '.last_review'
$slots = @('09:00', '13:00', '16:00')
$now = Get-Date
$slot = $null
for ($d = 0; $d -le 7 -and -not $slot; $d++) {
  $day = $now.Date.AddDays(-$d)
  if ($day.DayOfWeek -in 'Saturday', 'Sunday') { continue }
  foreach ($s in ($slots | Sort-Object -Descending)) {
    $t = $day.Add([TimeSpan]::Parse($s))
    if ($t -le $now) { $slot = $t; break }
  }
}
$last = (Get-Date).AddDays(-7)
if (Test-Path $lastFile) { try { $last = [datetime](Get-Content $lastFile -Raw).Trim() } catch {} }
if ($slot -and $last -lt $slot) {
  if (-not (Get-Process -Name 'Cursor*' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "$env:LOCALAPPDATA\Programs\CursorPrivateInference\Cursor Private Inference.exe" -ErrorAction SilentlyContinue
  }
  $msg = "Revue SCA en retard (derniere : {0:dd/MM HH:mm}).`nOuvre le chat SCA dans Cursor et ecris : revue" -f $last
  (New-Object -ComObject WScript.Shell).Popup($msg, 0, 'Revue SCA', 0x40) | Out-Null
}
