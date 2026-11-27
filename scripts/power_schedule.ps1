# Weekdays (Mon 00:00 -> Fri 20:00): never sleep on AC so the SCA watcher keeps running. Otherwise: back to 30 min.
# Battery (DC) settings are never touched. The screen still turns off and the session still locks.
param([int]$NormalMinutes = 30, [int]$FridayEndHour = 20)

$now = Get-Date
$weekday = $now.DayOfWeek -notin 'Saturday', 'Sunday'
$awake = $weekday -and -not ($now.DayOfWeek -eq 'Friday' -and $now.Hour -ge $FridayEndHour)

$minutes = if ($awake) { 0 } else { $NormalMinutes }
powercfg /change standby-timeout-ac $minutes
"{0:yyyy-MM-dd HH:mm} sleep on AC = {1}" -f $now, $(if ($awake) { 'never' } else { "$NormalMinutes min" })
