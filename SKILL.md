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

## 00. Startup: first thing in EVERY session (Baran, 27/11/2026)

"Premier truc quand tu te connectes, tu checkes tous les mails/Teams reçus (aussi sur le chat)." Do this before answering anything else, even if the first message is about something else:
1. **Timer**: check the terminals folder; if `review_timer.ps1` is not running, start it (see 0b, "Start the timer").
2. **SCA bot channel (the chat)**: `ListChannelMessages` with `include_replies: true` (team `c7392c17-827b-46f9-a22f-5a1397e62231`, channel `19:HguLtlDj-MhEZ5WNBzm9Xcykbhk_oKHRONSZKwRoypI1@thread.tacv2`). Every message or reply from Baran (author_id `064f7f49-19a4-473c-91a6-859a9bf5ff45`) newer than my last post in that thread is an instruction not yet handled: do it, then answer in the same thread. Also list my own unanswered questions still waiting for him.
3. **Mails**: `MailSearch` main mailbox + `shared_mailbox: superchargerhost@tesla.com` since `.last_quick` (or `.last_review` if later), apply 0b.
4. **Teams chats**: `ListChats` (limit 20) and read the ones with a new message since `.last_quick` that mention a site, vendor or LL of `watch_keywords.txt`.
5. Process `history/pending_sca.md`, then write `.last_quick`, save (`scripts/save.ps1`), and post one summary in the SCA bot channel only if something changed.

**How Baran reads / writes the chat**: Teams (PC or phone) > team **"SCA - Bot"** > channel **"SCA bot channel"**. My posts come from the Nova bot ("Sent by Baran Cokgul" footer), which triggers his phone notification. He answers by replying in the thread of a message, or with a new post. His own posts never raise a toast: they are caught by `scripts/teams_read.ps1` (Teams local cache) and by step 2 above.

**Response times (commitment)**
| Trigger | Detection | Answer |
| --- | --- | --- |
| Baran writes in the SCA bot channel | ~30 s (chat tick) while the PC is on with this Cursor chat open | do the action and reply in the thread within ~5 min; if it takes longer (SCA login, photos), post "je m'en occupe" first |
| Mail / Teams toast with a watched keyword | ~30 s + 2 min debounce (event tick) | ticket updated + Teams post within ~10 min |
| Missed toast (focus mode, notifications off) | hourly quick check 08:00-19:00 weekdays | same |
| Scheduled reviews | 09:00 / 13:00 / 16:00 weekdays | full report |
| PC off or chat closed | nothing runs | caught up by step 00 at the next session |

Never leave a message from Baran in the chat without an answer: if I cannot act (SCA logged out, missing info), say so in the thread.

## 0. Memory (always)

The goal is to handle SCA tickets autonomously over time.
- **Before acting**: read [sites.md](sites.md) for the sites involved (past issues, vendors, POs, LL answers) and [requests.md](requests.md) for how Baran decided similar cases. Propose actions based on them.
- **After each user instruction**: append it to `requests.md` (date, site, request, action, pattern).
- **After each action** (close, note, escalation, email sent, vendor/LL reply found): append a dated line to the site in `sites.md`, and create the site section if missing.
- When the same decision appears 2-3 times in `requests.md`, propose it as a rule. It goes into "Rules" only after Baran validates it.
- **History (training data for recommendations)**, in `history/`:
  - `decisions.jsonl`: one JSON line per ticket decision: date, site, ac, type, observed, agent_reco, decision (Baran), action, reason, match (did my reco match his decision). Before recommending, grep it for the same type of issue and follow his past decisions.
  - `closed_tickets.md`: every ticket closed (by me or by Baran) with the note and why.
  - `corrections.md`: every correction from Baran. Read it before acting.
  - `requests.md` (root): every instruction, verbatim-short, with the action taken.
- **Save automatically**: after every batch of actions run `scripts/save.ps1 -Message "<what>"` (git add/commit/push). Never wait for the end of the session.

## 0a. Autonomy (Baran, 26/11/2026)

"Je veux que tout soit fait automatiquement, que je n'ai pas à y toucher."
- When Baran gives an instruction, execute it end to end: send vendor / internal emails, close tickets, add notes, update files. Do not ask for approval for those.
- **Exception, LL emails (26/11/2026, "fais-moi relire les mails au LL")**: prepare them in superchargerhost Drafts (signature + photos), show the full text in the chat, and send only after Baran approves.
- When he says "OK with your reco", apply the recommendation fully.
- Only ask when information is genuinely missing (unknown contact, ambiguous site) and cannot be found in the sources below.
- Before sending anything, check Sent items and Drafts (main + superchargerhost) from the last hours: another session or Baran may already have done it. Reuse an existing draft (fix it, add photos) instead of creating a duplicate.
- Every email: his signature + the ticket photos (contact sheet via `montage.ps1` when there are many).
- After each email: add the dated English note on the SCA ticket.

## 0c. Data sources

- **Who built the site (IP) / DM / open date**: `TRT SuC France.xlsx` (SharePoint globalcharging, `.../Europe/Region Shared/France/`). `SearchSharePoint "TRT SuC France.xlsx"` then `ReadFileContent` (drive_item_id `01E652ANG77LS23WZOW5CI5THYZKILCB5Y`, drive_id `b!AgQlUz9YkEiEXxuqLcnnRehJGagFLGJBq_qP1wp9X8ie-x2bSErlTaSAHCo5Ip7y`). Output is big: parse `json_string.content`, save to %TEMP%\trt_france.md, grep the site. Sheet "DM Data" columns: SITE | stalls | WC | Solar | GPS | PSU | Region | Région RFP | Works QX | **DM** | **IP** | **Contact IP** | ... Sheet "TRT" has the open date; a second row for the same site = extension.
- **Site < 1 year old** -> ask the IP who built it first (warranty), then quote.
- **LL contacts**: search the main mailbox and superchargerhost first; otherwise `C:\Users\bcokgul\OneDrive - Tesla\Asset Management\Cursor\SCA\site_contacts.csv`.
- **Site history** (RAI responses, contacts, health): `scripts/site_lookup.ps1 -Site "<name>"` reads `site_contacts.csv`, `rai-responses.csv`, `supercharger_site_health.csv` in the same folder (open date, RAI counts by category, last RAI comments, LL / emergency contacts).
- Vendor emails seen: Circet Robin.FOURTON@circet.fr (main AM contact, South/Centre/Rhône-Alpes, also Normandy), Arnaud.BUREAU@circet.fr; SPIE michel.oribe@spie.com, benoit.colle@spie.com; R2 r.robinet@r2e2.fr, n.vatbled@r2e2.fr; BK bjoern.jantjes@bk-group.eu, Stefan.Maier@bk-group.eu.

## 0b. Scheduled email review (9:00, 13:00, 16:00, weekdays)

Requested by Baran on 26/11/2026. A local PowerShell timer (started in the chat, see "Start the timer" below) prints `AGENT_LOOP_TICK_sca_review` at each slot. On each tick:
0. If `history/pending_sca.md` has lines and SCA is logged in, process them first (close / notes), then empty the file.
1. Read `.last_review` in this skill folder (ISO time of the previous review; default: 8 h ago).
2. `MailSearch` the main mailbox and `shared_mailbox: superchargerhost@tesla.com` with `received_after` = that time, `top` 50, fields subject/from/receivedDateTime/bodyPreview. Ignore outage permits, invoices, newsletters and threads with no site in `sites.md` or the dashboard.
3. For each vendor or LL reply about an open ticket, read the body if needed and act:
   - Explicit completion ("intervention réalisée", "c'est fait", photos, LL confirms the fix or the rule) -> close the ticket with `closeTicketV2` and an evidence note.
   - Quote, date, PO, partial answer, refusal -> add a dated note with `addNoteSafe`.
   - LL says "on s'en occupe" on LL-owned infrastructure -> close (LL responsibility).
   - A reply that needs a simple answer (date confirmation, access code, PO number, thanks) -> reply and send. Anything involving money or a commitment not yet agreed by Baran -> report it.
4. Append the events to `sites.md` and `requests.md`, write the current time to `.last_review`, commit and push.
5. Post a short report in French: tickets closed, notes added, drafts waiting for approval, anything needing Baran.
6. **Teams (27/11/2026, Baran has no Cursor on his phone)**: post to the Teams team "SCA - Bot" (Baran only), channel "SCA bot channel", with `SendMessageAsNova` (`team_id: c7392c17-827b-46f9-a22f-5a1397e62231`, `channel_id: 19:HguLtlDj-MhEZ5WNBzm9Xcykbhk_oKHRONSZKwRoypI1@thread.tacv2`), markdown, prefix `**[Revue SCA hh:mm]**`. Nova-authored posts trigger his phone notifications (self-chat 48:notes does not). Post when something changes (ticket closed, vendor/LL reply) and when his input is needed (numbered questions with site + AC, LL draft text in full). Nothing new -> post nothing. At each review / quick check, read `ListChannelMessages` on that channel: replies from Baran are his answers - act, then reply in the same thread.
7. **Event trigger (tick `AGENT_LOOP_TICK_sca_event`, within ~30 s of a new mail/message)**: new Outlook (olk) has no COM and the WinRT `UserNotificationListener` is Denied for unpackaged apps, so `review_timer.ps1` reads a copy of the Windows notification database (`%LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db` + WAL) through the built-in `winsqlite3.dll` (`scripts/notif_read.ps1`, no Python needed). Every 30 s it takes toasts newer than `.last_notif_id` from Outlook (`Microsoft.OutlookForWindows`) or Teams (`MSTeams`), and if sender/subject/preview contains a word of `watch_keywords.txt` it prints an event tick with the toast text (debounced 2 min, max 5 toasts). On an event tick: `MailSearch` since `.last_quick`, process only the tickets concerned (section 0b), notify on Teams, write `.last_quick`. Keep `watch_keywords.txt` in sync when tickets open/close (sites, vendors, LL names).
   - Requires Outlook desktop notifications ON (Outlook > Settings > General > Notifications > "Show desktop notifications"; Windows Settings > System > Notifications > Outlook ON) and Teams notifications ON. Toasts only exist while the PC is on and unlocked/asleep-not-off.
   - Test: fire a toast with AUMID `MSTeams_8wekyb3d8bbwe!MSTeams` via `ToastNotificationManager` containing a keyword; an event tick appears within ~40 s (verified 27/11/2026).
8. **Fallback quick check (every 60 min, 08:00-19:00 weekdays, tick `AGENT_LOOP_TICK_sca_quick`)**: in case a toast was missed (notifications off, focus mode). `MailSearch` both mailboxes since `.last_quick`, read the Teams channel; act only on mails about open tickets, notify on Teams; write `.last_quick`. Do not reload the full dashboard. No relevant mail -> stop silently.
9. **Chat with Baran (tick `AGENT_LOOP_TICK_sca_chat`, within ~30 s)**: his own posts never raise a toast, so `scripts/teams_read.ps1` scans the new-Teams IndexedDB cache (`...\MSTeams\EBWebView\WV2Profile_tfw\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb`, `.log` + recent `.ldb`, latin1 view of V8 records) for messages in the SCA channel whose creator is `8:orgid:064f7f49-19a4-473c-91a6-859a9bf5ff45`; ids already handled are in `.seen_teams_ids`. Two record layouts exist (message records, and "lastMessage" records whose content is a UTF-16 string before `conversationLink ...;messageid=<root>" version "<id>"`); the reader handles both (layout B was missed until 27/11, so the Brest request of 15:07 went unanswered). On a chat tick: read the thread with `ListChannelMessages`, do what he asks (same rules as in the Cursor chat, LL emails still need his OK), answer in the same thread with `SendMessageAsNova` + `reply_to_message_id` (root message id). Requires Teams desktop running on the PC (it fills the cache).
- Timer notify pattern: `^AGENT_LOOP_TICK_sca_(review|quick|event|chat)`.
- If SCA asks for login or Outlook is down, report it and retry at the next slot. Never type credentials.
- Only one timer may run. Killing the Shell wrapper does NOT kill the child powershell: an orphan kept consuming Baran's Teams messages and toasts with ticks nobody saw (27/11, "Top envoie" missed). `review_timer.ps1` now kills any other `review_timer.ps1` process at start-up, so restarting it is always safe; never stop it with `Stop-Process` on the Shell PID.
- Start the timer at the start of EVERY SCA session: `Shell` with `block_until_ms: 0` and `notify_on_output` pattern `^AGENT_LOOP_TICK_sca_(review|quick|event|chat)`, running `scripts/review_timer.ps1`. It polls every 30 s and ticks as soon as a slot has passed without a review (`.last_review` older than the last slot), so missed slots (PC off, asleep, chat closed) are caught up immediately.
- Windows scheduled task "SCA weekday no-sleep" (27/11/2026, `scripts/power_schedule.ps1`, weekdays 06:00 + Friday 20:00 + logon): Mon-Fri never sleep on AC so the watcher keeps running; Friday 20:00 and weekends back to 30 min. Battery settings untouched; screen off and lock still apply. Lid action is not exposed on this PC (likely IT policy): keep the lid open or check that closing it does not sleep. A cloud-only setup is not possible: the Outlook/Teams MCPs go through the internal Nova host (`nova-host-agent-server.tesla.com`) and SCA is internal, both unreachable from Cursor cloud.
- Windows scheduled task "SCA review reminder" (registered 26/11/2026, `scripts/review_reminder.ps1`): weekdays 09:05 / 13:05 / 16:05 + at logon (+5 min), StartWhenAvailable (runs missed slots after the PC was off). If a review is late, it opens Cursor and shows a popup asking Baran to type "revue" in the SCA chat. A fully headless review is not possible: no Cursor agent CLI on this PC, and Cursor cloud Automations cannot reach the local Outlook MCP.
- When Baran types "revue" (or a tick arrives): restart the timer if it is not running, then run this section.

## 1. Login

1. `browser_tabs list`, then `browser_navigate` to the dashboard.
2. If redirected to `login.microsoftonline.com`, stop and ask the user to log in (email + MFA). Never type credentials. Resume when the user says so.

## 2. Read the dashboard

1. Wait ~8 s after navigation (Angular app, the first snapshot is empty).
2. **Grouped rows**: tickets on the same site are hidden under an "Expand" badge. Always expand all rows before reading (snippet `expandAll`). Check that the row count equals "Total Records" (`.tds-pagination-secondary--value`). Page size is 100.
3. Extract rows with the `extractRows` snippet. The response is large and goes to a file, so read the file.
4. Summarize for the user: total count, then priorities (safety/equipment > high severity > stale tickets with PO released and no update > amenities > site info to fix > quick closes > batches per vendor). Flag tickets with no AM note, misattributed sites, duplicates and out-of-scope countries.

## 3. Add an internal work note

On the ticket page, fill the textarea with placeholder "Add additional internal work notes." and click **Save Activity** (the small icon button next to the field is a filter, not submit). Verify that the note appears under "Internal Work Notes". Notes are written in English, **without a date prefix** (SCA already shows the date under each note; Baran, 27/11/2026).
- Wait ~5 s after the activity panel has loaded before filling the note: a save done right after load clears the textarea without saving.
- Never retry blindly: poll up to 20 s for the note to appear, and if it does not, reload the ticket and check before re-adding (a quick retry created a duplicate note on Montmarault).

### Assign / transfer a ticket to someone (proven method)

"Assign" adds someone; "transfer" or "give back" means the other person becomes the **sole** owner, so Baran must be unticked.
1. Open the ticket (`activity-detail/<AC>`), wait ~12-20 s until the panel shows "Activity Number:<AC>" (the first screenshot is often a spinner).
2. Fresh screenshot > click the chevron next to "Preparation Owner" (around x=877, y=399 in the side panel) with `browser_mouse_click_xy`. A dropdown opens with the search box "Assign User" (ref in the snapshot, `searchbox` "Search") and the current owners ticked.
3. `browser_type` the **full name** in the search box (e.g. `Andrea Van der Aalst`), wait ~3 s, fresh screenshot, check the job title under the name (e.g. "Sr. Market Asset Manager, Charging Southern Europe"), tick its checkbox by mouse.
4. To remove Baran: `browser_fill` the search box with `""` to show the full list again, fresh screenshot, untick "Baran Cokgul" by mouse.
5. Add the note in the textarea and click **Save Activity** via JS (the dropdown can stay open). The save also commits the owner change.
6. Verify: read the text after "Preparation Owner" in `document.body.innerText`; it must list only the new owner.
- Note template: `Hi <first name>, <what you need / answer>. Assigning the ticket (back) to you. Thanks!`
- Owners by topic: navigation, access code, entrance or site description -> **Tim Oster** (toster, Charging Nav / UI / Site Maps). Greece, Spain and other Southern Europe sites -> **Andrea Van der Aalst** (avanderaalst, Sr. Market AM Southern Europe). Morocco is in Baran's scope (do not transfer).
- When Tim asks a question in the notes (e.g. "is access code X correct?"), answer in the note and make Tim sole owner again.
- A transferred ticket leaves Baran's dashboard ("Total Records" drops by 1).

### Escalate to field teams

Dashboard row > **Escalate** > "Escalate To Field Teams" (Preparation Status: Prepared) > Correction Codes: type a keyword (e.g. `Light`) and pick by mouse (e.g. `EN50SEN50E5405240 - Site level - Lighting (Restored)`) > Narrative: what to check on the next site visit > **Escalate**. Toast: "Activity Escalated Successfully"; the ticket leaves the AM dashboard.

## 4. Download ticket photos

1. Ticket page > "Attachments" tab > collect `a[href*="dms-storage-api"]` (Download links).
2. `fetch` is blocked (CORS). Open each link with `browser_navigate` in a **new tab**: the file lands in `%USERPROFILE%\Downloads` as `<guid>.tmp`, or under its original name (`.jpg`, `.heic`).
3. **Download one file at a time and wait ~8 s** before moving it. Moving the newest file too early grabs the previous download and shifts every file by one. After a batch, check hashes (`Get-FileHash`): two identical hashes mean a shift. Check that the photo content matches the site (plates, shops, country).
4. Right after each download, run `scripts/grab.ps1 -Site "<Site>" -Name "<Topic>" -AC <AC>` (in this skill folder). It takes the newest file in Downloads (last 40 s), detects the type from the magic bytes (`FF D8` = JPEG, `ftyp` = HEIC, PNG, PDF) and moves it to **`Desktop\SCA\<Site>\<Topic>_<AC>.<ext>`** (adds `_2`, `_3` if the name exists). Baran asked for this folder so he can find every ticket photo without clicking anything.
5. View the image to confirm it is usable and matches the site. HEIC (iPhone) photos cannot be decoded on this PC (no HEIF codec), so rely on the ticket text instead.
6. Desktop is `C:\Users\bcokgul\OneDrive - Tesla\Desktop`; the SCA photo root is `C:\Users\bcokgul\OneDrive - Tesla\Desktop\SCA`. Upload to email drafts from that folder.
5. Closing a tab with `browser_tabs close` can close every tab, so re-navigate afterwards.

## 5. Close a ticket

Always confirm the list of tickets to close with the user (AskQuestion) before closing.

From the dashboard, the row's **Close** quick action opens "Close Activity <AC>" with a note field. Use the `closeTicket` snippet (it expands parent rows for child tickets). Then handle the blockers.

**Proven loop (7 closures in a row on 26/11/2026, no failure):**
1. `browser_navigate` to the dashboard (reload before **each** ticket, so no stale dialog remains), wait ~10 s.
2. Run `closeTicketV2` (reference.md): it waits for "Total Records", expands every group, opens Close on the row, fills the note, polls up to 10 s for the Close button to enable, clicks it, and returns `clicked close, total before N`.
3. The next reload shows `total before N-1`: that is the confirmation the previous close worked.
4. If it returns `close disabled: ... Please enter a Fault Mode`, the dialog is still open: fresh screenshot > click "Select a Fault Mode" (around x=476, y=398) > `browser_type` the keyword (e.g. `Site Damage`) > wait 2-3 s > fresh screenshot > click the option > wait ~7 s (dialog reloads, Fault Mode field disappears, Close turns blue) > fresh screenshot > click **Close**. Toast "Activity Closed".
5. At the end, reload, expand all and check that none of the closed ACs is still listed.
- Tickets with an existing fault mode (most RAI tickets) close directly. Tickets created manually or from Digiwrench without fault mode ask for one (e.g. Tournus "Bin need to be replaced" -> `F-0154 - Site Damage`).
- The closing note is the internal note: write the evidence in it (who, when, what), no separate note needed.

Blockers:

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
- Attach photos to every RFQ / LL / third-party email when the ticket has some, without asking the user to click anything: list the ticket's `dms-storage` links, open each one in a spare tab (it downloads silently to Downloads), wait ~7 s, move it with an explicit name, check the image, then `GetPresignedUploadUrl` -> `curl.exe -X PUT` with `Content-Type` + `Content-Range: bytes 0-(size-1)/size` -> `ConfirmUpload` -> `AttachFile` on each draft. If SCA has no attachment (photos only in the Bolt form), reuse the photos from a previous email with `DownloadAttachment` (base64 `content`). Shared-mailbox drafts accept files < 3 MB only.
- Signature: drafts must end with Baran's signature block (name, "Sr. Market Asset Manager, Charging Western Europe", address, confidentiality line). For reply drafts, put the signature in the `body` of the reply/reply_all call; updating the body afterwards wipes the quoted thread. The Nova tool appends "Sent via Nova" automatically.
- Vendor contacts: Circet Robin Fourton (Robin.FOURTON@circet.fr, coordinates regions; Circet Ouest Jeremi Citeau, Est Abdellah Alami, Anthony Sivignon), R2 Nicolas Vatbled (n.vatbled@r2e2.fr), SPIE Michel Oribe (michel.oribe@spie.com) and Benoit Collé (benoit.colle@spie.com), Facility Partner BE Frédéric Job (frederic@facilitypartner.be), Reeload BE Raf Seeldrayers, Dynamic Arthur Silva, BK World Björn Jantjes.
- Replying to a thread whose last message was sent by Baran (`reply` / `reply_all`) addresses the draft to Baran himself. Fix it with an `update` of `to` only (keeps the quoted thread). Always check the `to` field returned by the tool.
- To fix a typo in a reply draft, delete it and recreate the reply (updating the body wipes the quoted thread).
- `AttachFile` can fail with "file service get failed" (500) on a given upload. Retrying the same file_id does not help: do a new `GetPresignedUploadUrl` + PUT + `ConfirmUpload` and attach the new file_id.
- Police / gendarmerie for a site: search `lannuaire.service-public.gouv.fr/recherche?whoWhat=gendarmerie&where=<Commune>+(<CP>)` with `WebFetch`, take the nearest "Brigade de gendarmerie" (not "Peloton d'autoroute" unless the site is on the motorway), open its page for phone/address. Brigades publish no email. For an abandoned car, the land owner (LL) files the report; we give plate, photo and the brigade contact.
- Bolt forms (`grid.tesla.com/forms/<id>`, link in the Digiwrench note): open them in a **new tab** (`browser_navigate` with `newTab: true`). The first attempt may ask for SSO; once SCA is logged in, the form loads (an "Insufficient Access" banner can show, ignore it). Photos are `blob:` images. Only the ones inside a "Site Condition Issue N" block matter (the "Post Issue N" blocks are post cosmetics). Use the `boltSitePhotos` snippet (reference.md) to download them, then `grab_batch.ps1`.
- Ticket photos, fastest way: on the ticket page, run the `ticketPhotos` snippet (reference.md). It opens the Attachments tab, clicks every `dms-storage` link with a 2.5 s gap (downloads without leaving the page) and returns `{since, count}`. Then `scripts/grab_batch.ps1 -Site <Site> -Name <Topic> -Count <count> -Since <since> -AC <AC>` waits for all files to be complete and files them in `Desktop\SCA\<Site>\<Topic>_<n>_<AC>.jpg`.
- To look at photos: `scripts/preview.ps1 -Site <Site>` (resized copies in %TEMP%\sca_preview) or `scripts/montage.ps1 -Site <Site> [-Filter "Topic*"]` (one numbered contact sheet). Always look before describing the issue: the ticket category is often wrong (e.g. Chilly "bollards" = enclosure gate lock, Dardilly Nord "landscaping" = overflowing bin, Aire-sur-l'Adour "engine" = a construction lift).
- HEIC photos (iPhone, often from vendors by email): convert to JPG with WPF (`[Windows.Media.Imaging.BitmapDecoder]::Create(...)` + `JpegBitmapEncoder`), it works on this PC. Email attachments come from `DownloadAttachment` (base64, saved to a file when large); skip small inline images (logos).
- Email attachments: request presigned URLs and attach **one file at a time** (GetPresignedUploadUrl -> `scripts/upload.ps1` -> ConfirmUpload -> AttachFile, then the next file). Requesting several upload URLs in parallel made AttachFile fail with "file service get failed".
- Leases are on SharePoint `globalcharging/.../Europe Sites/<Country>/01_Fully_Operational/<Site>/Lease/` (search `<Site> lease`). Read with `ReadFileContent` and grep the text for access/parking/fee clauses.

## Session log

Factual record of what was done, to reuse as worked examples. Decisions here are NOT rules unless they also appear in "Rules".

### 25/11/2026
- Dashboard 71 -> 53. Closed: Narbonne/Rivesaltes duplicates (F-0154), Caylar (misattributed), 6 ICEing tickets (one-off user decision, Mons kept), Cesson ("Issue resolved"), Senlis (retrofit), Rivesaltes stickers ("Service has closed the case"), Rouen flood ("No action to take - checked with LL"), Arc-sur-Tille / Poitiers Sud / Mâcon / Magnant amenity tickets ("Resolved", all > 1 week old).
- Beauvais lighting: escalated to field teams, code `Site level - Lighting (Restored)`, narrative "check the lighting poles at next visit".
- Poitiers Futuroscope navigation: assigned to Tim Oster with a note.
- Dated notes added on 10 tickets from vendor emails (Antwerp, Kortrijk, Le Bosc x2, Gap, Montmarault, Brest, Chasse, Montélimar, Caen).
- 26/11: 13 emails sent after approval (Montmarault and Verviers held). Narbonne mail to Circet re-done without SPIE. SCA notes pending (session expired, user must log in).
- Emails drafted (16): Falaise RFQ to R2 / Circet / SPIE separately (no vendor contacted yet), PO follow-ups citing PO numbers on existing threads (Saint-Parres, Laxou, Chasse, Montélimar), quote chasers (Brest, Montmarault), Narbonne to Circet+SPIE / SPIE / Facility Partner, R2 Caen WC removal check, EV Connexion sticker warning, Bègles drain to Klépierre LL, Roissy (Van der Valk Paris CDG, Avenue du Bois de la Pie) and Verviers (Valk, contract art. 1.1 open 24/7) kept as drafts for user review.

## Rules

- Execute Baran's instructions end to end without asking (see 0a). When a vendor or LL email gives explicit evidence (work done, LL confirms the fix or takes it over), add the note or close the ticket directly, then report it.
- **All SCA notes and closing notes in English.** Emails to French/Belgian LLs and vendors in French.
- **Cleanliness (litter, bins full, dirty site) = LL**, except sites where Tesla has its own cleaning vendor (e.g. GSF Athena at Poitiers Sud) or an amenity operator (BK sites, e.g. Sénas, Dardilly Nord). Broken / unanchored equipment (bin pulled out, hole) = vendor repair.
- Small debris in the technical zone (leaves under cabinets) -> techs clean during their visit, close without RFQ.
- Sites planned for closure (e.g. Aire du Poulet de Bresse, closing next year) -> no investment, close cosmetic tickets.
- Cosmetic damage on equipment that still works (cracked luminaire with working lighting) -> no intervention, close.
- Signage issues without ICEing reports -> not urgent, close; think about the signage layout as a whole.
- Never fill Bolt forms with invented data. Fix the correction code instead, or ask the user.
- Never type credentials.
- Report every ticket that could not be closed, with the exact SCA message.
- Amenity tickets (toilets clogged/out of order, lounge, coffee machine, fridge): older than 1 week -> close with `Resolved.`; 1 week old or less -> forward the case to Björn Jantjes (BK World, bjoern.jantjes@bk-group.eu). Still confirm the list with the user before closing.
- PO released but no intervention date -> chase the vendor on the existing email thread (reply all) and quote the PO number and amount.
- One email per company: never put vendors from different companies in the same email (to, cc or bcc), even when several companies are consulted on the same topic. Colleagues of the same company can be in copy.
- Emails to landlords: draft in superchargerhost (shared_mailbox), Baran in cc, show it to Baran and send only after his OK. Subject `Tesla | <Site>, <Country> | <Issue>`, written in French for French and Belgian sites.
