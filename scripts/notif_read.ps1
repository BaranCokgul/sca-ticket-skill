param([int]$Last = 15, [long]$SinceId = 0)

if (-not ('WinSqlite' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinSqlite {
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_open_v2([MarshalAs(UnmanagedType.LPStr)] string f, out IntPtr db, int flags, IntPtr vfs);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_prepare_v2(IntPtr db, [MarshalAs(UnmanagedType.LPStr)] string sql, int n, out IntPtr stmt, IntPtr tail);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_step(IntPtr stmt);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern long sqlite3_column_int64(IntPtr stmt, int i);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern IntPtr sqlite3_column_blob(IntPtr stmt, int i);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_column_bytes(IntPtr stmt, int i);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_finalize(IntPtr stmt);
  [DllImport("winsqlite3.dll", CallingConvention = CallingConvention.StdCall)] public static extern int sqlite3_close(IntPtr db);
  public static string Text(IntPtr stmt, int i) {
    int n = sqlite3_column_bytes(stmt, i); if (n <= 0) return "";
    byte[] b = new byte[n]; Marshal.Copy(sqlite3_column_blob(stmt, i), b, 0, n);
    return System.Text.Encoding.UTF8.GetString(b);
  }
}
'@
}

# The live DB is locked by Windows: read a copy (with its WAL so the latest toasts are included).
$src = "$env:LOCALAPPDATA\Microsoft\Windows\Notifications\wpndatabase.db"
$dir = Join-Path $env:TEMP 'sca_wpn'; New-Item -ItemType Directory -Force $dir | Out-Null
foreach ($ext in '', '-wal', '-shm') { if (Test-Path "$src$ext") { Copy-Item "$src$ext" "$dir\n.db$ext" -Force } }

$db = [IntPtr]::Zero
if ([WinSqlite]::sqlite3_open_v2("$dir\n.db", [ref]$db, 1, [IntPtr]::Zero) -ne 0) { throw 'open failed' }
$sql = "select n.Id, n.ArrivalTime, h.PrimaryId, n.Payload from Notification n join NotificationHandler h on h.RecordId = n.HandlerId where n.Id > $SinceId and n.Type = 'toast' order by n.Id desc limit $Last"
$st = [IntPtr]::Zero
if ([WinSqlite]::sqlite3_prepare_v2($db, $sql, -1, [ref]$st, [IntPtr]::Zero) -ne 0) { [WinSqlite]::sqlite3_close($db) | Out-Null; throw 'prepare failed' }
$out = while ([WinSqlite]::sqlite3_step($st) -eq 100) {
  $payload = [WinSqlite]::Text($st, 3)
  $texts = [regex]::Matches($payload, '<text[^>]*>(.*?)</text>', 'Singleline') | ForEach-Object { [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value.Trim()) }
  [pscustomobject]@{
    Id      = [WinSqlite]::sqlite3_column_int64($st, 0)
    Time    = [datetime]::FromFileTimeUtc([WinSqlite]::sqlite3_column_int64($st, 1)).ToLocalTime()
    App     = [WinSqlite]::Text($st, 2)
    Title   = ($texts | Select-Object -First 1)
    Body    = (($texts | Select-Object -Skip 1) -join ' | ')
  }
}
[WinSqlite]::sqlite3_finalize($st) | Out-Null
[WinSqlite]::sqlite3_close($db) | Out-Null
$out
