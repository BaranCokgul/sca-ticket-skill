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

On the ticket page, fill the textarea with placeholder "Add additional internal work notes." and click **Save Activity** (the small icon button next to the field is a filter, not submit). Verify that the note appears under "Internal Work Notes". Notes are written in English and dated by SCA.

## 4. Download ticket photos

1. Ticket page > "Attachments" tab > collect `a[href*="dms-storage-api"]` (Download links).
2. `fetch` is blocked (CORS). Open each link with `browser_navigate` in a **new tab**: the file lands in `%USERPROFILE%\Downloads` as `<guid>.tmp`.
3. Check the magic bytes (`FF D8` = JPEG), copy the file to the target folder with an explicit name (`<Site>_<topic>_<AC>.jpg`), delete the `.tmp` files, and view the image to confirm it is usable.
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

The dropdowns are search textboxes: click them with `browser_click`/`browser_mouse_click_xy`, use `browser_type`, then click the option in a screenshot (option text is not exposed to JS). Inputs may be `pointer-events: none` during loading, so wait 2-3 s.

### Default fault modes (search keyword -> option)

- Water / sealing / flood -> `F-7566 - Water Intrusion` (or `F-8827 - Pooling Water` for drains)
- Enclosure damage -> `F-0003 - Enclosure - Water Damage` only if it is water, otherwise search "enclosure" / "damage"
- Other topics: search "vandal", "damage", "light", "landscap", "sign", "bin" and take the closest. If nothing fits, keep the fault mode already on the ticket.

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

## Lessons learned

- The dialog text read right after clicking Close can be stale. If the table count dropped, the close worked. Confirm on the ticket page (Status: Closed).
- Fuzed "Intervention maintenance" emails are payment kiosk works, not AM tickets. Outage permit emails do not prove a repair either.
- MailSearch: `search_keywords` must go inside the `input` JSON string. Words with `-` or quoted phrases in OR lists cause KQL syntax errors.
- The GitHub MCP (github.tesla.com) can return 401. Ask the user to re-authenticate it in Cursor. The skill folder is a local git repo, so push when access works.
- Teams search matches person names (e.g. "Aalst" = Andrea Van der Aalst). Do not treat those hits as site evidence.

## Rules

- Never close, edit or note a ticket without user confirmation of the list.
- Never fill Bolt forms with invented data. Fix the correction code instead, or ask the user.
- Never type credentials.
- Report every ticket that could not be closed, with the exact SCA message.
