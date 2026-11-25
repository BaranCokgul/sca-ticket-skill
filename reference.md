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
