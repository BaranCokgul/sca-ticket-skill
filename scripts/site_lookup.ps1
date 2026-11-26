param([Parameter(Mandatory)][string]$Site, [int]$Rai = 15)
$d = "C:\Users\bcokgul\OneDrive - Tesla\Asset Management\Cursor\SCA"
function Load($f) { Get-Content (Join-Path $d $f) -Encoding UTF8 | Select-Object -Skip 2 | ConvertFrom-Csv }
$pat = [regex]::Escape($Site)

"=== SITE HEALTH"
Load 'supercharger_site_health.csv' | Where-Object { $_.site_name -match $pat } |
  Select-Object trt_id, site_name, project_type, post_count, open_to_public_date, rai_count_6m, rai_site_cleanliness, rai_overgrown_landscaping, most_common_issue_label, total_sessions_6m |
  Format-List | Out-String -Width 250

"=== CONTACTS"
Load 'site_contacts.csv' | Where-Object { $_.site_name -match $pat -or $_.common_site_name -match $pat } |
  Select-Object site_name, contact_type, site_role, contact_role, company, contact_name, contact_title, email_address, phone, modified_date |
  Sort-Object site_role, contact_type | Format-Table -AutoSize | Out-String -Width 400

"=== RAI (last $Rai)"
Load 'rai-responses.csv' | Where-Object { $_.Site -match $pat } |
  Sort-Object { [datetime]$_.'Survey Start' } -Descending | Select-Object -First $Rai |
  ForEach-Object { "{0} | {1} | {2} | {3} | {4}" -f $_.'Survey Start', $_.Category, $_.Status, $_.SCA, ($_.Comments -replace '\s+', ' ').Substring(0, [Math]::Min(150, ($_.Comments -replace '\s+', ' ').Length)) }
