$slots = @('09:00', '13:00', '16:00')
$quickEveryMin = 15
$quickStart = [TimeSpan]::Parse('08:00')
$quickEnd = [TimeSpan]::Parse('19:00')
$prompt = 'Revue SCA programmee : lis les mails recus depuis la derniere revue (boite perso + superchargerhost) et les reponses de Baran dans le canal Teams SCA bot, traite history/pending_sca.md, mets a jour ou ferme les tickets selon la section 0b du skill sca-tickets, puis fais le compte rendu.'
$quickPrompt = 'Controle rapide SCA : lis les mails recus depuis .last_quick (boite perso + superchargerhost) et les reponses de Baran dans le canal Teams SCA bot. Si un mail concerne un ticket ouvert (prestataire, LL, avocat), applique la section 0b sur ce ticket uniquement et notifie Baran sur Teams. Sinon ne fais rien et ne poste rien.'
$root = Split-Path $PSScriptRoot -Parent
$lastFile = Join-Path $root '.last_review'
$quickFile = Join-Path $root '.last_quick'

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

function Get-Stamp([string]$file, [datetime]$default) {
  if (Test-Path $file) { try { return [datetime](Get-Content $file -Raw).Trim() } catch {} }
  return $default
}

function Tick { Write-Output ('AGENT_LOOP_TICK_sca_review {"prompt":"' + $prompt + '"}') }
function QuickTick { Write-Output ('AGENT_LOOP_TICK_sca_quick {"prompt":"' + $quickPrompt + '"}') }

$lastTick = Get-Date '2000-01-01'
$lastQuickTick = Get-Date '2000-01-01'
while ($true) {
  $now = Get-Date
  $slot = Get-LastSlot $now
  $lastReview = Get-Stamp $lastFile $now.AddDays(-1)
  # Catch-up: a slot passed (PC off, asleep, chat closed) and no review was done since -> tick now.
  if ($slot -and $lastReview -lt $slot -and $lastTick -lt $slot) {
    Tick
    $lastTick = $now
  }
  elseif ($now.DayOfWeek -notin 'Saturday', 'Sunday' -and $now.TimeOfDay -ge $quickStart -and $now.TimeOfDay -lt $quickEnd) {
    $lastCheck = @((Get-Stamp $quickFile $now.AddHours(-1)), $lastReview) | Sort-Object -Descending | Select-Object -First 1
    if (($now - $lastCheck).TotalMinutes -ge $quickEveryMin -and ($now - $lastQuickTick).TotalMinutes -ge $quickEveryMin) {
      QuickTick
      $lastQuickTick = $now
    }
  }
  # Wall-clock polling so that sleep/hibernate does not shift the schedule.
  Start-Sleep -Seconds 60
}
