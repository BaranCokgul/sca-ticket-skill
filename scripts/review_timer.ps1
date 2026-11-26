$slots = @('09:00', '13:00', '16:00')
$prompt = 'Revue SCA programmee : lis les mails recus depuis la derniere revue (boite perso + superchargerhost), traite history/pending_sca.md, mets a jour ou ferme les tickets selon la section 0b du skill sca-tickets, puis fais le compte rendu.'
$lastFile = Join-Path (Split-Path $PSScriptRoot -Parent) '.last_review'

function Get-LastSlot([datetime]$now) {
  for ($d = 0; $d -le 7; $d++) {
    $day = $now.Date.AddDays(-$d)
    if ($day.DayOfWeek -in 'Saturday', 'Sunday') { continue }
    foreach ($s in ($slots | Sort-Object -Descending)) {
      $t = $day.Add([TimeSpan]::Parse($s))
      if ($t -le $now) { return $t }
    }
  }
}

function Get-LastReview {
  if (Test-Path $lastFile) { try { return [datetime](Get-Content $lastFile -Raw).Trim() } catch {} }
  return (Get-Date).AddDays(-1)
}

function Tick { Write-Output ('AGENT_LOOP_TICK_sca_review {"prompt":"' + $prompt + '"}') }

$lastTick = Get-Date '2000-01-01'
while ($true) {
  $now = Get-Date
  $slot = Get-LastSlot $now
  # Catch-up: a slot passed (PC off, asleep, chat closed) and no review was done since -> tick now.
  if ($slot -and (Get-LastReview) -lt $slot -and $lastTick -lt $slot) {
    Tick
    $lastTick = $now
  }
  # Wall-clock polling so that sleep/hibernate does not shift the schedule.
  Start-Sleep -Seconds 60
}
