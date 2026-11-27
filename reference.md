# SCA JS snippets

Run with `browser_cdp` > `Runtime.evaluate`, `returnByValue: true`, and `awaitPromise: true` for async snippets.

## expandAll (dashboard)

Expands the grouped rows and returns row count vs Total Records.

```js
(async()=>{for(const b of document.querySelectorAll('tds-icon-button[aria-label="Expand"] button')){b.click();await new Promise(r=>setTimeout(r,500));}await new Promise(r=>setTimeout(r,1500));return {rows:document.querySelectorAll('tbody tr').length,total:(document.querySelector('.tds-pagination-secondary--value')||{}).innerText}})()
```

## extractRows (dashboard)

Returns one block per ticket (AC, site, severity, narrative, notes, dates). Powerflow boilerplate is stripped.

```js
(()=>[...document.querySelectorAll('tbody tr')].map(r=>{const m=(r.innerText.match(/AC55530[0-9A-F]{7}/)||[])[0];return m?r.innerText.replace(/From Powerflow:[\s\S]*?ledger/g,'').replace(/\s*\n\s*/g,' | ').slice(0,1200):''}).filter(Boolean).join('\n\n'))()
```

## closeTicket (dashboard)

Set `id`, `parent` (AC of the visible parent row if the ticket is grouped, else null) and `note`. Returns `closed`, `close disabled: <dialog text>` (a blocker to handle) or an error.

```js
(async()=>{const id='AC...';const parent=null;const note='...';
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const find=()=>[...document.querySelectorAll('tbody tr')].find(r=>r.innerText.includes(id));
let row=find();
if(!row&&parent){const p=[...document.querySelectorAll('tbody tr')].find(r=>r.innerText.includes(parent));const eb=p&&p.querySelector('tds-icon-button[aria-label="Expand"] button');if(eb){eb.click();await sleep(1500);}row=find();}
if(!row)return 'row not found';
row.scrollIntoView({block:'center'});
[...row.querySelectorAll('button,a')].find(b=>b.innerText.trim()==='Close').click();await sleep(1500);
const dlg=[...document.querySelectorAll('.cdk-overlay-pane,[role=dialog],.tds-modal')].find(d=>d.innerText.includes('Close Activity '+id));
if(!dlg)return 'no dialog';
const t=dlg.querySelector('textarea');t.focus();t.value=note;t.dispatchEvent(new Event('input',{bubbles:true}));await sleep(500);
const b=[...dlg.querySelectorAll('button')].find(x=>x.innerText.trim()==='Close');
if(b.disabled)return 'close disabled: '+dlg.innerText.slice(0,400);
b.click();await sleep(3500);
return find()?'STILL LISTED (reload to confirm)':'closed';})()
```

## closeTicketV2 (dashboard, preferred)

Run right after loading the dashboard. Set `id` and `note`. Expands all groups itself, so no `parent` needed. Returns `clicked close, total before N`, `close disabled: <dialog text>` (blocker, dialog left open) or `row not found, total N`.

```js
(async()=>{const id='AC...';const note='...';const sleep=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<20&&!document.querySelector('.tds-pagination-secondary--value');i++)await sleep(1000);await sleep(1500);
const tot=document.querySelector('.tds-pagination-secondary--value').innerText;
for(const b of document.querySelectorAll('tds-icon-button[aria-label="Expand"] button')){b.click();await sleep(400);}await sleep(1500);
const find=()=>[...document.querySelectorAll('tbody tr')].find(r=>r.innerText.includes(id));
let row=find();if(!row)return 'row not found, total '+tot;row.scrollIntoView({block:'center'});
[...row.querySelectorAll('button,a')].find(b=>b.innerText.trim()==='Close').click();await sleep(2000);
const dlg=[...document.querySelectorAll('.cdk-overlay-pane,[role=dialog],.tds-modal')].find(d=>d.innerText.includes('Close Activity '+id));
if(!dlg)return 'no dialog';
const t=dlg.querySelector('textarea');t.focus();t.value=note;t.dispatchEvent(new Event('input',{bubbles:true}));
let b;for(let i=0;i<10;i++){await sleep(1000);b=[...dlg.querySelectorAll('button')].find(x=>x.innerText.trim()==='Close');if(b&&!b.disabled)break;}
if(b.disabled)return 'close disabled: '+dlg.innerText.slice(0,500);
b.click();await sleep(4000);return 'clicked close, total before '+tot})()
```

## addNoteSafe (ticket page, preferred)

Waits for the ticket to load, skips if the note already exists, waits 5 s, saves, polls 20 s. Returns `saved`, `already there`, `not ready` or `not confirmed`.

```js
(async()=>{const id='AC...';const note='...';const sleep=ms=>new Promise(r=>setTimeout(r,ms));let t;
for(let i=0;i<30;i++){if(document.body.innerText.includes(id)){t=[...document.querySelectorAll('textarea')].find(x=>x.placeholder&&x.placeholder.startsWith('Add additional'));if(t)break;}await sleep(1000);}
if(!t)return 'not ready';if(document.body.innerText.includes(note.slice(0,50)))return 'already there';
await sleep(5000);t.click();t.focus();t.value=note;t.dispatchEvent(new Event('input',{bubbles:true}));t.dispatchEvent(new Event('change',{bubbles:true}));await sleep(1500);
const b=[...document.querySelectorAll('button')].find(x=>x.innerText.trim()==='Save Activity');if(!b)return 'no save btn';b.click();
for(let i=0;i<20;i++){await sleep(1000);if(document.body.innerText.includes(note.slice(0,50)))return 'saved';}return 'not confirmed'})()
```

Batch pattern: for each ticket, one message with `browser_navigate` (activity-detail URL) + `AwaitShell` 12 s + this snippet. 12 notes in a row worked on 26/11/2026.

## ticketPhotos (ticket page)

```js
(async()=>{const id='AC...';const sleep=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<25&&!document.body.innerText.includes(id);i++)await sleep(1000);await sleep(3000);
const tab=[...document.querySelectorAll('[role=tab]')].find(e=>/^Attachments/.test(e.innerText.trim()));if(tab){tab.click();await sleep(3000);}
const links=[...new Set([...document.querySelectorAll('a')].filter(x=>/dms-storage/.test(x.href)).map(x=>x.href))];
const since=new Date(Date.now()-2000).toISOString();
for(const l of links){const a=document.createElement('a');a.href=l;document.body.appendChild(a);a.click();a.remove();await sleep(2500);}
return JSON.stringify({since,count:links.length})})()
```

Then in PowerShell: `& scripts\grab_batch.ps1 -Site "<Site>" -Name "<Topic>" -Count <count> -Since ([datetime]"<since>").ToLocalTime() -AC <AC>`.

## boltSitePhotos (Grid form tab)

```js
(async()=>{const sleep=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<15&&![...document.querySelectorAll('img')].some(x=>x.src.startsWith('blob:'));i++)await sleep(1000);await sleep(2000);
const seen=new Set();const items=[];
for(const img of document.querySelectorAll('img')){if(!img.src.startsWith('blob:')||seen.has(img.src))continue;let el=img,lab=null;
 for(let i=0;i<12&&el;i++){el=el.parentElement;const t=el&&el.innerText||'';const m=t.match(/^\s*Site Condition Issue (\d+)/);if(m){lab=m[1];break;}if(/Post Issue \d+|Charge Post Checks/.test(t))break;}
 if(lab){seen.add(img.src);items.push({src:img.src,lab});}}
const since=new Date(Date.now()-2000).toISOString();
for(const it of items){const a=document.createElement('a');a.href=it.src;a.download='site_issue_'+it.lab+'.jpg';document.body.appendChild(a);a.click();a.remove();await sleep(1500);}
return JSON.stringify({since,count:items.length,labels:items.map(i=>i.lab)})})()
```

One Bolt form can cover several tickets (one per Site Condition Issue): rename the files with the right AC afterwards.

## Read the owner / status of a ticket

```js
(()=>{const s=document.body.innerText;const k=s.indexOf('Preparation Owner');return s.slice(k,k+80).replace(/\n/g,' ')+' | '+(s.match(/Status\n[^\n]*/)||[''])[0]})()
```

A row can still look listed right after closing because the table has not re-rendered. Reload the dashboard and check "Total Records" before retrying.

## addNote (ticket page)

```js
(async()=>{const t=[...document.querySelectorAll('textarea')].find(x=>x.placeholder.startsWith('Add additional'));t.focus();t.value='...';t.dispatchEvent(new Event('input',{bubbles:true}));await new Promise(r=>setTimeout(r,500));const b=[...document.querySelectorAll('button')].find(x=>x.innerText.trim()==='Save Activity');if(b.disabled)return 'save disabled';b.click();await new Promise(r=>setTimeout(r,4000));const tx=document.body.innerText;const i=tx.indexOf('Internal Work Notes');return tx.slice(i,i+300)})()
```

Check the ticket number first: `document.body.innerText.match(/Activity Number:[^\n]*/)`.

## listAttachments (ticket page)

```js
(async()=>{const tab=[...document.querySelectorAll('[role=tab],button,a,li,span')].find(e=>e.innerText&&e.innerText.trim().startsWith('Attachments')&&e.innerText.length<20);tab.click();await new Promise(r=>setTimeout(r,2500));return [...document.querySelectorAll('a')].filter(x=>/dms-storage/.test(x.href)).map(x=>x.href)})()
```

## Save a downloaded attachment (PowerShell)

```powershell
$d="C:\Users\bcokgul\OneDrive - Tesla\Desktop\<Folder>"; New-Item -ItemType Directory -Force -Path $d | Out-Null
$src=(Get-ChildItem "$env:USERPROFILE\Downloads" -Filter *.tmp | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
Copy-Item $src "$d\<Site>_<topic>_<AC>.jpg"; Remove-Item "$env:USERPROFILE\Downloads\*.tmp"
```
