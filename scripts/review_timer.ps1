$slots = @('09:00', '13:00', '16:00')
$prompt = 'Revue SCA programmee : lis les mails recus depuis la derniere revue (boite perso + superchargerhost), mets a jour ou ferme les tickets selon la section 0b du skill sca-tickets, puis fais le compte rendu.'
while ($true) {
  $now = Get-Date
  $next = $null
  for ($d = 0; $d -le 7 -and -not $next; $d++) {
    $day = $now.Date.AddDays($d)
    if ($day.DayOfWeek -in 'Saturday', 'Sunday') { continue }
    foreach ($s in $slots) {
      $t = $day.Add([TimeSpan]::Parse($s))
      if ($t -gt $now) { $next = $t; break }
    }
  }
  Write-Output ("next review: {0:ddd dd/MM HH:mm}" -f $next)
  Start-Sleep -Seconds ([int][Math]::Ceiling(($next - (Get-Date)).TotalSeconds))
  Write-Output ('AGENT_LOOP_TICK_sca_review {"prompt":"' + $prompt + '"}')
}
