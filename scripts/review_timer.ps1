$slots = @('09:00', '13:00', '16:00')
$quickEveryMin = 60
$quickStart = [TimeSpan]::Parse('08:00')
$quickEnd = [TimeSpan]::Parse('19:00')
$eventDebounceSec = 120
$prompt = 'Revue SCA programmee : lis les mails recus depuis la derniere revue (boite perso + superchargerhost) et les reponses de Baran dans le canal Teams SCA bot, traite history/pending_sca.md, mets a jour ou ferme les tickets selon la section 0b du skill sca-tickets, puis fais le compte rendu.'
$quickPrompt = 'Controle rapide SCA : lis les mails recus depuis .last_quick (boite perso + superchargerhost) et les reponses de Baran dans le canal Teams SCA bot. Si un mail concerne un ticket ouvert (prestataire, LL, avocat), applique la section 0b sur ce ticket uniquement et notifie Baran sur Teams. Sinon ne fais rien et ne poste rien.'
$eventPrompt = 'Evenement SCA : une notification Outlook/Teams correspond a un site ou prestataire suivi (details ci-dessous). Lis les mails depuis .last_quick, traite selon la section 0b uniquement les tickets concernes, notifie Baran sur le canal Teams SCA bot, mets a jour .last_quick.'
$root = Split-Path $PSScriptRoot -Parent
$lastFile = Join-Path $root '.last_review'
$quickFile = Join-Path $root '.last_quick'
$notifIdFile = Join-Path $root '.last_notif_id'
$kwFile = Join-Path $root 'watch_keywords.txt'
$notifReader = Join-Path $PSScriptRoot 'notif_read.ps1'
$teamsReader = Join-Path $PSScriptRoot 'teams_read.ps1'
$teamsSeenFile = Join-Path $root '.seen_teams_ids'
$chatPrompt = 'Message de Baran dans le canal Teams SCA bot (details ci-dessous). Lis le fil avec ListChannelMessages (team c7392c17-827b-46f9-a22f-5a1397e62231, canal SCA bot channel), fais ce qu il demande selon le skill sca-tickets, puis reponds-lui dans le meme fil avec SendMessageAsNova (reply_to_message_id = id du message racine).'
$watchedApps = 'OutlookForWindows|MSTeams|Outlook'

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

function Get-Keywords {
  if (-not (Test-Path $kwFile)) { return @() }
  Get-Content $kwFile -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim() }
}

function Esc([string]$s) { ($s -replace '[\r\n"\\]', ' ').Trim() }

function Tick { Write-Output ('AGENT_LOOP_TICK_sca_review {"prompt":"' + $prompt + '"}') }
function QuickTick { Write-Output ('AGENT_LOOP_TICK_sca_quick {"prompt":"' + $quickPrompt + '"}') }
function EventTick([string]$detail) { Write-Output ('AGENT_LOOP_TICK_sca_event {"prompt":"' + $eventPrompt + ' ' + (Esc $detail) + '"}') }
function ChatTick([string]$detail) { Write-Output ('AGENT_LOOP_TICK_sca_chat {"prompt":"' + $chatPrompt + ' ' + (Esc $detail) + '"}') }

# Seed the Teams cursor so that only messages posted after start-up trigger a reply.
if (-not (Test-Path $teamsSeenFile)) {
  try { @(& $teamsReader) | ForEach-Object { $_.Id } | Set-Content $teamsSeenFile } catch { Set-Content $teamsSeenFile '' }
}

# Seed the notification cursor so that only toasts arriving after start-up are considered.
if (-not (Test-Path $notifIdFile)) {
  try { $top = & $notifReader -Last 1 | Select-Object -First 1; Set-Content $notifIdFile ([string]($(if ($top) { $top.Id } else { 0 }))) } catch { Set-Content $notifIdFile '0' }
}

$lastTick = Get-Date '2000-01-01'
$lastQuickTick = Get-Date '2000-01-01'
$lastEventTick = Get-Date '2000-01-01'
$pending = New-Object System.Collections.Generic.List[string]
$iter = 0
while ($true) {
  $now = Get-Date

  # Event watcher: new Outlook/Teams toasts matching a watched keyword (every 30 s).
  try {
    $sinceId = [long](Get-Content $notifIdFile -Raw).Trim()
    $new = @(& $notifReader -Last 50 -SinceId $sinceId)
    if ($new.Count) {
      Set-Content $notifIdFile ([string](($new | Measure-Object Id -Maximum).Maximum))
      $kws = Get-Keywords
      foreach ($n in ($new | Where-Object { $_.App -match $watchedApps } | Sort-Object Id)) {
        $text = "$($n.Title) $($n.Body)"
        $hit = $kws | Where-Object { $text -match ('(?i)(^|\W)' + [regex]::Escape($_) + '(\W|$)') } | Select-Object -First 1
        if ($hit) { $pending.Add(('[{0}] {1} : {2} (mot-cle {3})' -f ($n.App -replace '_.*', ''), $n.Title, $n.Body, $hit)) }
      }
    }
  } catch {}
  # Chat watcher: Baran's own posts in the SCA channel never raise a toast, so read the Teams cache (every 30 s).
  try {
    $seenIds = @(Get-Content $teamsSeenFile -ErrorAction SilentlyContinue | Where-Object { $_ })
    $newMsgs = @(& $teamsReader | Where-Object { $seenIds -notcontains [string]$_.Id })
    if ($newMsgs.Count) {
      $newMsgs | ForEach-Object { [string]$_.Id } | Add-Content $teamsSeenFile
      ChatTick (($newMsgs | ForEach-Object { 'id {0} (fil {1}) : {2}' -f $_.Id, $_.ParentId, $_.Text }) -join ' || ')
    }
  } catch {}

  if ($pending.Count -and ($now - $lastEventTick).TotalSeconds -ge $eventDebounceSec) {
    EventTick (($pending | Select-Object -First 5) -join ' || ')
    $pending.Clear()
    $lastEventTick = $now
  }

  if ($iter % 2 -eq 0) {
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
  }
  $iter++
  # Wall-clock polling so that sleep/hibernate does not shift the schedule.
  Start-Sleep -Seconds 30
}
