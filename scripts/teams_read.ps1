param(
  [string]$ChannelId = '19:HguLtlDj-MhEZ5WNBzm9Xcykbhk_oKHRONSZKwRoypI1@thread.tacv2',
  [string]$UserOrgId = '064f7f49-19a4-473c-91a6-859a9bf5ff45',
  [int]$MaxAgeHours = 48
)

# New Teams keeps its message cache in a Chromium IndexedDB (LevelDB). Records are V8-serialised, so a
# latin1 view of the raw bytes is enough to find Baran's messages in the SCA channel without a LevelDB parser.
# Two record layouts exist:
#  A) message records: conversationId ... parentMessageId ... version ... creator ... content (one-byte string)
#  B) conversation "lastMessage" records: content (often a two-byte UTF-16 string) ... from 8:orgid ...
#     conversationLink "conversation/<channel>;messageid=<root>" ... version "<id>"
$dir = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\WV2Profile_tfw\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb"
if (-not (Test-Path $dir)) { return }
$latin1 = [Text.Encoding]::GetEncoding(28591)
$chan = [regex]::Escape($ChannelId)
$user = [regex]::Escape($UserOrgId)
$rxA = [regex]::new('conversationId".' + $chan + '".{0,600}?parentMessageId".(\d{13}).{0,400}?version".(\d{13}).{0,2000}?creator".{1,3}8:orgid:' + $user + '".content".(.{0,1500}?)".contentHash', 'Singleline')
$rxB = [regex]::new('conversation/' + $chan + ';messageid=(\d{13})".version".(\d{13})', 'Singleline')

function Clean([string]$t) { ($t -replace '<[^>]+>', ' ' -replace '[^\x20-\x7E\xC0-\xFF]', '' -replace '\s+', ' ').Trim() }

# Reads the V8 string value that follows the key `"\x07content` at $pos: tag '"' = latin1, 'c' = UTF-16LE.
function Read-V8String([string]$s, [int]$pos) {
  $tag = $s[$pos]; $i = $pos + 1; $len = 0; $shift = 0
  do { $b = [int]$s[$i]; $len += ($b -band 0x7F) -shl $shift; $shift += 7; $i++ } while ($b -band 0x80 -and $shift -lt 28)
  if ($len -le 0 -or $i + $len -gt $s.Length) { return '' }
  $raw = $s.Substring($i, $len)
  if ($tag -eq 'c') { return [Text.Encoding]::Unicode.GetString($latin1.GetBytes($raw)) }
  if ($tag -eq '"') { return $raw }
  ''
}

$seen = @{}
$files = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.log', '.ldb' -and $_.LastWriteTime -gt (Get-Date).AddHours(-$MaxAgeHours) }
foreach ($f in $files) {
  try {
    $fs = [IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite,Delete')
    $buf = New-Object byte[] $fs.Length; [void]$fs.Read($buf, 0, $buf.Length); $fs.Close()
  } catch { continue }
  $s = $latin1.GetString($buf)
  foreach ($m in $rxA.Matches($s)) {
    $id = $m.Groups[2].Value
    if (-not $seen.ContainsKey($id)) { $seen[$id] = [pscustomobject]@{ Id = [long]$id; ParentId = [long]$m.Groups[1].Value; Text = (Clean $m.Groups[3].Value) } }
  }
  foreach ($m in $rxB.Matches($s)) {
    $id = $m.Groups[2].Value
    if ($seen.ContainsKey($id)) { continue }
    $start = [Math]::Max(0, $m.Index - 6000)
    $win = $s.Substring($start, $m.Index - $start)
    $k = $win.LastIndexOf([string][char]0x22 + [char]0x07 + 'content')
    if ($k -lt 0) { continue }
    if ($win.Substring($k) -notmatch ('8:orgid:' + $user)) { continue }
    $text = Clean (Read-V8String $win ($k + 9))
    if ($text) { $seen[$id] = [pscustomobject]@{ Id = [long]$id; ParentId = [long]$m.Groups[1].Value; Text = $text } }
  }
}
$seen.Values | Sort-Object Id
