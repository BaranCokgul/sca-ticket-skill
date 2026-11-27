param(
  [string]$ChannelId = '19:HguLtlDj-MhEZ5WNBzm9Xcykbhk_oKHRONSZKwRoypI1@thread.tacv2',
  [string]$UserOrgId = '064f7f49-19a4-473c-91a6-859a9bf5ff45',
  [int]$MaxAgeHours = 48
)

# New Teams keeps its message cache in a Chromium IndexedDB (LevelDB). Records are V8-serialised, so a
# latin1 view of the raw bytes is enough to find Baran's messages in the SCA channel without a LevelDB parser.
$dir = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\WV2Profile_tfw\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb"
if (-not (Test-Path $dir)) { return }
$latin1 = [Text.Encoding]::GetEncoding(28591)
$chan = [regex]::Escape($ChannelId)
$user = [regex]::Escape($UserOrgId)
$rx = [regex]::new('conversationId".' + $chan + '".{0,600}?parentMessageId".(\d{13}).{0,400}?version".(\d{13}).{0,2000}?creator".{1,3}8:orgid:' + $user + '".content".(.{0,1500}?)".contentHash', 'Singleline')

$seen = @{}
$files = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.log', '.ldb' -and $_.LastWriteTime -gt (Get-Date).AddHours(-$MaxAgeHours) }
foreach ($f in $files) {
  try {
    $fs = [IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite,Delete')
    $buf = New-Object byte[] $fs.Length; [void]$fs.Read($buf, 0, $buf.Length); $fs.Close()
  } catch { continue }
  $s = $latin1.GetString($buf)
  foreach ($m in $rx.Matches($s)) {
    $id = $m.Groups[2].Value
    if ($seen.ContainsKey($id)) { continue }
    $text = $m.Groups[3].Value -replace '<[^>]+>', ' ' -replace '[^\x20-\x7E\xC0-\xFF]', '' -replace '\s+', ' '
    $seen[$id] = [pscustomobject]@{ Id = [long]$id; ParentId = [long]$m.Groups[1].Value; Text = $text.Trim() }
  }
}
$seen.Values | Sort-Object Id
