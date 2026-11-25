---
name: sca-tickets
description: Reviews, updates and closes Asset Management tickets in Tesla Service Center App (SCA, serviceapp.tesla.com) through the Cursor browser - reads the MLOC energy dashboard, triages actions and recommendations, adds internal work notes, downloads ticket photos, cross-checks Outlook/Teams for completed work, and closes tickets (fault mode, equipment, correction code, Bolt form blockers). Use when the user mentions SCA, Service App, serviceapp, energy dashboard 5018, MLOC, tickets to check/close, or asks to close/update Supercharger site tickets.
disable-model-invocation: true
---

# SCA tickets (Asset Management)

There is no MCP for SCA. Everything goes through the `cursor-ide-browser` MCP. Outlook (`user-mail`) and Teams (`user-microsoft-teams`) MCPs are used to find evidence of completed work.

Dashboard: `https://serviceapp.tesla.com/service/energy-dashboards/5018` (Asset Manager view, filter "Pending Charging Network Asset Management").
Ticket: `https://serviceapp.tesla.com/service/service-home/activity-detail/<AC...>`

JS snippets referenced below are in [reference.md](reference.md).

## 1. Login

1. `browser_tabs list`, then `browser_navigate` to the dashboard.
2. If redirected to `login.microsoftonline.com`, stop and ask the user to log in (email + MFA). Never type credentials. Resume when the user says so.

## 2. Read the dashboard

1. Wait ~8 s after navigation (Angular app, the first snapshot is empty).
2. **Grouped rows**: tickets on the same site are hidden under an "Expand" badge. Always expand all rows before reading (snippet `expandAll`). Check that the row count equals "Total Records" (`.tds-pagination-secondary--value`). Page size is 100.
3. Extract rows with the `extractRows` snippet. The response is large and goes to a file, so read the file.
4. Summarize for the user: total count, then priorities (safety/equipment > high severity > stale tickets with PO released and no update > amenities > site info to fix > quick closes > batches per vendor). Flag tickets with no AM note, misattributed sites, duplicates and out-of-scope countries.

## 3. Add an internal work note

On the ticket page, fill the textarea with placeholder "Add additional internal work notes." and click **Save Activity** (the small icon button next to the field is a filter, not submit). Verify that the note appears under "Internal Work Notes". Notes are written in English, prefixed `[dd/mm/yyyy]`.
- Wait ~5 s after the activity panel has loaded before filling the note: a save done right after load clears the textarea without saving.
- Never retry blindly: poll up to 20 s for the note to appear, and if it does not, reload the ticket and check before re-adding (a quick retry created a duplicate note on Montmarault).

### Assign a ticket to someone

"Preparation Owner" field in the activity panel > click the owner name > search box "Assign User" > type the full name (first name alone returns dozens of homonyms) > tick the checkbox > add a note addressed to the person > **Save Activity**. The field is multi-select: the previous owner stays unless unticked.
- Navigation, access, entrance or site-description issues: **Tim Oster** (toster, Charging Nav / UI / Site Maps).

### Escalate to field teams

Dashboard row > **Escalate** > "Escalate To Field Teams" (Preparation Status: Prepared) > Correction Codes: type a keyword (e.g. `Light`) and pick by mouse (e.g. `EN50SEN50E5405240 - Site level - Lighting (Restored)`) > Narrative: what to check on the next site visit > **Escalate**. Toast: "Activity Escalated Successfully"; the ticket leaves the AM dashboard.

## 4. Download ticket photos

1. Ticket page > "Attachments" tab > collect `a[href*="dms-storage-api"]` (Download links).
2. `fetch` is blocked (CORS). Open each link with `browser_navigate` in a **new tab**: the file lands in `%USERPROFILE%\Downloads` as `<guid>.tmp`, or under its original name (`.jpg`, `.heic`).
3. **Download one file at a time and wait ~8 s** before moving it. Moving the newest file too early grabs the previous download and shifts every file by one. After a batch, check hashes (`Get-FileHash`): two identical hashes mean a shift. Check that the photo content matches the site (plates, shops, country).
4. Check the magic bytes (`FF D8` = JPEG, `ftyp` at offset 4 = HEIC), move the file to the target folder with an explicit name (`<Site>_<topic>_<AC>.jpg`), and view the image to confirm it is usable. HEIC (iPhone) photos cannot be decoded on this PC (no HEIF codec, WPF gives a black image), so rely on the ticket text instead.
4. Desktop is `C:\Users\bcokgul\OneDrive - Tesla\Desktop`.
5. Closing a tab with `browser_tabs close` can close every tab, so re-navigate afterwards.

## 5. Close a ticket

Always confirm the list of tickets to close with the user (AskQuestion) before closing.

From the dashboard, the row's **Close** quick action opens "Close Activity <AC>" with a note field. Use the `closeTicket` snippet (it expands parent rows for child tickets). Then handle the blockers:

| Dialog message | Fix |
|---|---|
| "Please enter a Fault Mode" | Type a keyword in "Select a Fault Mode" and pick the closest match (see defaults below). |
| "Please select Equipment before closing Activity" | Type `S` in "Select an equipment" and pick **Supercharger Site : SUPERCHARGER SITE STE...** (site-level item, first option). Use a post/cabinet only if the ticket is about one specific post. |
| "Please submit all the required bolt forms" | The correction code is "No Valid Correction Code Found" (00003194), which triggers the "Persona Mapping/New Code Requests" form. Open the ticket > Correction Codes > **+ CORRECTION** > pick a valid code (see defaults) > Save > delete 00003194 (trash icon > Confirm) > **Save Activity** > close again from the dashboard. |

The dropdowns are search textboxes:
1. Open **one** dialog at a time. If dialogs stack, reload the dashboard. A JS-filled textarea can land in a hidden stale dialog.
2. Click the field with `browser_mouse_click_xy` (fresh screenshot first), then `browser_type` with the returned ref.
3. List the options with JS: `[...document.querySelectorAll('.tds-mpd__option-label')].map(o=>o.textContent.trim())`.
4. Select with `browser_mouse_click_xy` on a fresh screenshot. A JS `.click()` on the option does not register.
5. After selection the dialog reloads (spinner, "Fault Mode must be provided..." banner) for ~5 s, then shows only the note and an enabled Close button. Reading the Close button state immediately after opening can wrongly show it as disabled.

### Default fault modes (search keyword -> option)

There is no "landscaping", "vegetation" or "duplicate" fault mode. Typing "Site" lists the site-level ones.
- Generic default (duplicates, landscaping, vegetation, misc site issue) -> `F-0154 - Site Damage`
- ICEing / blocked stalls -> `F-8824 - Non-EV's blocking site` or `F-8839 - Site Partially Blocked`
- Vandalism / graffiti -> `F-0004 - Site Vandalism`
- Flooding -> `F-8841 - Site Flooded`. Water / sealing -> `F-7566 - Water Intrusion` (or `F-8827 - Pooling Water` for drains)
- Enclosure door -> `F-7653 - Enclosure Door Issue`. Water in enclosure -> `F-0003 - Enclosure - Water Damage`
- Snow -> `F-11532 - Snow Removal Needed - Full Site`
- Access -> `F-11663 - Unable to Locate or Get to Site`

### Default correction codes

| Topic | Code |
|---|---|
| Bins replaced/installed | `Site level - Waste Bin (Installed Only)` EN50SEN50E5575140 |
| Trash/debris | `Site - Trash/Debris Removed` SCS-334099 |
| Landscaping | `Site level - Landscaping (Performed)` EN50SEN50E5395170 |
| Lighting | `Site level - Lighting (Restored)` / `(Installed Only)` |
| Signage | `Site level - Signage (Replaced)` / `(Restored)` |
| Enclosure | `Site - Enclosure Repaired` SCS-329654 / `Exterior - Enclosure (Repaired)` |
| Bollard | `Site level - Bollard (Replaced)` |
| Graffiti / stickers | `Site level - Graffiti Removal (Performed)` |
| Duplicate ticket | `System Data - Duplicate Ticket [Other]` SCS-43-1002 |
| Solved in another ticket | `ResolvedByOtherActivity` 00008055 |
| Fault no longer present / no action | `Site - Diagnosis - Fault Is No Longer Present [Other]` SCS-37-1002 |

### Closing note templates (English)

- Duplicate: `Duplicate of <AC> (<topic>) - follow-up in that ticket. Closing.`
- Work done: `<Work> completed by <vendor> on <dd/mm/yyyy> (<evidence: email/photos/PO>). Closing.`
- No action: `<Topic> - not a Tesla asset / no action needed (<who confirmed>). Closing.`
- Covered by project: `Site will be retrofitted - <issue> will be repaired as part of the retrofit works. Closing.`

### Verify

Reload the dashboard, expand all rows, check that the AC is gone and that "Total Records" dropped. Or open the ticket and check **Status: Closed**.

## 6. Find closable tickets in Outlook/Teams

1. Mail search per vendor (Circet, Reeload, CKS, Citeos, Fuzed...) and per site name since ~2 months (`MailSearch`, `fields` without `body`, `top` up to 40). KQL rejects `-` and quotes inside OR lists, so use single words (e.g. `Parres`, `Tille`).
2. Teams `SearchMessages` is noisy (names like "Aalst" match people). Use it as a complement only.
3. Closable only with explicit completion evidence (vendor "intervention OK / changement OK" + photos, LL confirmation). A released PO or a planned date is not completion: propose a follow-up note instead.
4. Present closable tickets and follow-up updates separately, then ask what to do.

## 7. Closable without new evidence (ticket content only)

Scan the expanded dashboard for:
- **Consolidated tickets**: a sibling ticket has a note like "Using this ticket to combine X + Y" or "Consolidating ... in one ticket". Close the absorbed ticket as duplicate of the one that carries the work.
- **Same site, same issue**: two pre-departure inspections reporting the same thing (e.g. landscaping twice) are duplicates. Keep the oldest or the one with notes.
- **Misattributed site**: a note says "not the right site" and the work is tracked elsewhere (another AC or a service ticket). Close with `ResolvedByOtherActivity` and reference the AC.
- **Duplicate links**: CNOC agents paste "additional report: <AC>" links. The newest ticket is usually the duplicate.
- Out-of-scope countries (e.g. Greece, Morocco) should be reassigned, not closed.

## 8. ICEing tickets (blocked stalls)

For each ticket, collect: creation date, days in status, severity, number of linked reports (CNOC notes "Multiple reports", "Additional report: <AC>"), customer note, and the photos (check that they show the right site).
- **Keep open** when the problem recurs (several reports, High severity, photos showing non-EVs or idle cars). Action: LL/operator signage, enforcement, or parking marking.
- **Closable** when it was a single report, it is older than ~45 days and nothing new came in. Note template: `Single ICEing report on <date>, no recurrence since. Closing - will reopen if new reports.`
- Photos showing EVs parked without being plugged in point to idle fees or LL enforcement, not ICE signage.
- ICEing tickets closed without a Fault Mode or Equipment prompt. A batch close in one JS loop works, but the dialog stops on the first blocker. The "Total Records" counter lags, so reload and check each AC.

## Lessons learned

- The dialog text read right after clicking Close can be stale. If the table count dropped, the close worked. Confirm on the ticket page (Status: Closed).
- Fuzed "Intervention maintenance" emails are payment kiosk works, not AM tickets. Outage permit emails do not prove a repair either.
- MailSearch: `search_keywords` must go inside the `input` JSON string. Words with `-` or quoted phrases in OR lists cause KQL syntax errors.
- The skill folder `~/.cursor/skills/sca-tickets` is a git repo whose remote is `https://github.com/BaranCokgul/sca-ticket-skill.git` (github.com, not github.tesla.com). After each skill update, commit with `git -c user.name="Baran Cokgul" -c user.email="bcokgul@tesla.com" commit -am "<msg>"` and run `git push`. Do not change the git config.
- The Tesla GitHub MCP (github.tesla.com) returned 401 and is not used for this repo.
- `activity-detail/<AC>` redirects to `product-details/...#activity-<AC>`, and CDP may fail with "Execution context was destroyed". Wait ~12 s after navigation, or navigate to the final product-details URL directly.
- Teams search matches person names (e.g. "Aalst" = Andrea Van der Aalst). Do not treat those hits as site evidence.
- Close dialog: the Close button can read as disabled for a few seconds after the note is filled. Poll up to ~8 s for it to enable before treating it as a blocker.
- "WC" in AM notes can mean **Wall Connector** (e.g. Caen St Contest), not toilets. Check the vendor thread.
- Email: drafts are created with `MailCompose` (reply_all on the latest vendor thread to keep history; LL emails from `shared_mailbox: superchargerhost@tesla.com`). Show the drafts and get explicit approval before `send`. Subject format: `Tesla | <Site>, <Country> | <Topic>` (French for FR/BE sites).
- Vendor contacts: Circet Robin Fourton (Robin.FOURTON@circet.fr, coordinates regions; Circet Ouest Jeremi Citeau, Est Abdellah Alami, Anthony Sivignon), R2 Nicolas Vatbled (n.vatbled@r2e2.fr), SPIE Michel Oribe (michel.oribe@spie.com) and Benoit Collé (benoit.colle@spie.com), Facility Partner BE Frédéric Job (frederic@facilitypartner.be), Reeload BE Raf Seeldrayers, Dynamic Arthur Silva, BK World Björn Jantjes.
- Leases are on SharePoint `globalcharging/.../Europe Sites/<Country>/01_Fully_Operational/<Site>/Lease/` (search `<Site> lease`). Read with `ReadFileContent` and grep the text for access/parking/fee clauses.

## Rules

- Never close, edit or note a ticket without user confirmation of the list.
- Never fill Bolt forms with invented data. Fix the correction code instead, or ask the user.
- Never type credentials.
- Report every ticket that could not be closed, with the exact SCA message.
