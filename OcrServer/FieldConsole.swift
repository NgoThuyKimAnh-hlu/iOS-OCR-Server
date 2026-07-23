//
//  FieldConsole.swift
//  OcrServer
//

import Foundation

enum FieldConsole {
    static func html(port: Int) -> String {
        #"""
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Compute Field Console</title>
          <style>
            :root {
              --ink:#eef2e8; --muted:#98a69c; --panel:#101a17; --line:#2b3b33;
              --signal:#b7f36b; --amber:#ffba5c; --danger:#ff756d; --black:#07100d;
            }
            * { box-sizing:border-box; }
            html,body { max-width:100%; overflow-x:hidden; }
            body {
              margin:0; min-height:100vh; color:var(--ink); background:
                radial-gradient(circle at 12% 6%,#28402d 0,transparent 34%),
                linear-gradient(135deg,#050b09,#0b1712 52%,#111b16);
              font-family:Georgia,"Times New Roman",serif;
            }
            body::before {
              content:""; position:fixed; inset:0; pointer-events:none; opacity:.13;
              background-image:linear-gradient(#fff 1px,transparent 1px),linear-gradient(90deg,#fff 1px,transparent 1px);
              background-size:42px 42px;
            }
            main { position:relative; width:min(1050px,calc(100% - 28px)); margin:auto; padding:34px 0 60px; }
            header { display:flex; justify-content:space-between; gap:24px; align-items:end; margin-bottom:24px; }
            .eyebrow,.mono { font-family:"SFMono-Regular",Consolas,monospace; }
            .eyebrow { color:var(--signal); font-size:12px; letter-spacing:.2em; text-transform:uppercase; }
            h1 { margin:7px 0 0; max-width:680px; font-size:clamp(38px,8vw,78px); line-height:.88; font-weight:500; letter-spacing:-.055em; }
            .node { text-align:right; color:var(--muted); font-size:12px; line-height:1.7; }
            .grid { display:grid; grid-template-columns:minmax(0,1.5fr) minmax(280px,.7fr); gap:16px; min-width:0; }
            .card { min-width:0; max-width:100%; background:linear-gradient(145deg,#14221d,#0b1411); border:1px solid var(--line); border-radius:22px; padding:20px; box-shadow:0 22px 70px #0007; }
            .drop { min-height:265px; display:grid; place-items:center; text-align:center; border:1px dashed #52705c; border-radius:16px; padding:28px; cursor:pointer; transition:.18s ease; }
            .drop.hot { border-color:var(--signal); background:#b7f36b0c; transform:translateY(-2px); }
            .drop strong { display:block; font-size:29px; font-weight:500; }
            .drop span { display:block; max-width:100%; color:var(--muted); margin-top:9px; line-height:1.5; overflow-wrap:anywhere; }
            input[type=file] { display:none; }
            label { display:block; color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:.12em; margin-bottom:8px; }
            select,button { width:100%; color:var(--ink); border:1px solid var(--line); border-radius:12px; background:#07110d; padding:13px 14px; font:600 14px "SFMono-Regular",Consolas,monospace; }
            button { margin-top:12px; cursor:pointer; color:#0a100c; background:var(--signal); border-color:var(--signal); }
            button:disabled { cursor:not-allowed; opacity:.35; }
            .note { margin-top:18px; padding:14px; border-left:3px solid var(--amber); color:#d7ddcf; background:#ffba5c0c; font-size:14px; line-height:1.55; }
            .progress { margin-top:16px; height:8px; overflow:hidden; border-radius:99px; background:#050a08; border:1px solid var(--line); }
            .bar { width:0; height:100%; background:linear-gradient(90deg,var(--amber),var(--signal)); transition:width .22s ease; }
            .status { min-height:22px; margin-top:10px; color:var(--muted); font:12px/1.5 "SFMono-Regular",Consolas,monospace; }
            .files { margin-top:16px; display:grid; gap:8px; }
            .file { display:grid; grid-template-columns:1fr auto; gap:10px; padding:10px 12px; background:#07110d; border:1px solid #1d2b25; border-radius:10px; font:12px "SFMono-Regular",Consolas,monospace; }
            .file small { color:var(--muted); }
            .result { border-color:#3c5545; }
            .result.bad { border-color:#713c39; color:#ffd6d2; }
            footer { margin-top:18px; color:var(--muted); font:12px/1.6 "SFMono-Regular",Consolas,monospace; }
            @media (max-width:760px) {
              main { width:100%; padding:24px 14px 48px; }
              header { align-items:start; flex-direction:column; min-width:0; }
              h1 { max-width:100%; font-size:clamp(34px,12vw,52px); line-height:.92; overflow-wrap:anywhere; }
              .node { width:100%; text-align:left; }
              .grid { width:100%; grid-template-columns:minmax(0,1fr); }
              .grid > * { width:100%; min-width:0; }
              .card { padding:16px; }
              .drop { min-width:0; padding:22px 12px; }
              select,button { min-width:0; }
            }
          </style>
        </head>
        <body><main>
          <header>
            <div><div class="eyebrow">Field appliance / offline</div><h1>Turn scans into working files.</h1></div>
            <div class="node mono">PHONE NODE :\#(port)<br>SEQUENTIAL / ON-DEVICE<br>NO CLOUD REQUIRED</div>
          </header>
          <div class="grid">
            <section class="card">
              <div id="drop" class="drop" role="button" tabindex="0">
                <div><strong>Drop a stack here</strong><span>Images and PDFs. Files are sent one at a time<br>to keep the phone cool.</span></div>
              </div>
              <input id="picker" type="file" accept="image/*,application/pdf" multiple>
              <div id="files" class="files"></div>
            </section>
            <aside class="card">
              <label for="operation">Output</label>
              <select id="operation">
                <option value="ocr">OCR contract JSON</option>
                <option value="markdown">Markdown</option>
                <option value="docx">Word (.docx)</option>
              </select>
              <button id="run" disabled>Run sequential batch</button>
              <div class="progress"><div id="bar" class="bar"></div></div>
              <div id="status" class="status">Waiting for files.</div>
              <div class="note"><strong>Offline use:</strong> connect the browser device through Personal Hotspot or the same Wi-Fi. OCR and Markdown stay fully on-device. Word files are assembled here in the browser, not on the phone.</div>
            </aside>
          </div>
          <section class="card" style="margin-top:16px"><div class="eyebrow">Completed files</div><div id="results" class="files"></div></section>
          <footer>Routes: /batch/ocr · /batch/markdown · /batch/docx · Toggle each route and this console from /admin/services.</footer>
        </main>
        <script>
          const $ = id => document.getElementById(id);
          const encoder = new TextEncoder();
          let selected = [];

          function sizeLabel(bytes) {
            if (bytes < 1024) return bytes + ' B';
            if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
            return (bytes / 1048576).toFixed(1) + ' MB';
          }
          function safeBase(name) {
            return (name.replace(/\.[^.]+$/, '').replace(/[^a-zA-Z0-9._-]+/g, '_') || 'result').slice(0, 120);
          }
          function renderFiles() {
            $('files').innerHTML = selected.map((file, index) => `<div class="file"><span>${escapeHTML(file.name)}</span><small>${index + 1} / ${sizeLabel(file.size)}</small></div>`).join('');
            $('run').disabled = selected.length === 0;
            $('status').textContent = selected.length ? `${selected.length} file(s) queued.` : 'Waiting for files.';
          }
          function escapeHTML(value) {
            return value.replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
          }
          function addFiles(files) {
            const known = new Set(selected.map(file => `${file.name}:${file.size}:${file.lastModified}`));
            for (const file of files) {
              const key = `${file.name}:${file.size}:${file.lastModified}`;
              if (!known.has(key)) { selected.push(file); known.add(key); }
            }
            renderFiles();
          }

          const drop = $('drop');
          drop.onclick = () => $('picker').click();
          drop.onkeydown = event => { if (event.key === 'Enter' || event.key === ' ') $('picker').click(); };
          $('picker').onchange = event => addFiles(event.target.files);
          for (const eventName of ['dragenter','dragover']) drop.addEventListener(eventName, event => { event.preventDefault(); drop.classList.add('hot'); });
          for (const eventName of ['dragleave','drop']) drop.addEventListener(eventName, event => { event.preventDefault(); drop.classList.remove('hot'); });
          drop.addEventListener('drop', event => addFiles(event.dataTransfer.files));

          function le16(value) {
            const out = new Uint8Array(2); new DataView(out.buffer).setUint16(0, value, true); return out;
          }
          function le32(value) {
            const out = new Uint8Array(4); new DataView(out.buffer).setUint32(0, value >>> 0, true); return out;
          }
          function concat(parts) {
            const length = parts.reduce((sum, part) => sum + part.length, 0);
            const out = new Uint8Array(length); let offset = 0;
            for (const part of parts) { out.set(part, offset); offset += part.length; }
            return out;
          }
          function crc32(data) {
            let crc = 0xffffffff;
            for (const byte of data) {
              crc ^= byte;
              for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
            }
            return (crc ^ 0xffffffff) >>> 0;
          }
          function dosStamp(date) {
            const time = (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1);
            const year = Math.max(1980, date.getFullYear());
            const day = ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
            return {time, day};
          }
          async function entryBytes(value) {
            if (typeof value === 'string') return encoder.encode(value);
            if (value instanceof Uint8Array) return value;
            return new Uint8Array(await value.arrayBuffer());
          }
          async function makeZip(entries) {
            const locals = [], centrals = []; let offset = 0;
            const stamp = dosStamp(new Date());
            for (const entry of entries) {
              const name = encoder.encode(entry.name); const data = await entryBytes(entry.data); const crc = crc32(data);
              const local = concat([le32(0x04034b50),le16(20),le16(0x0800),le16(0),le16(stamp.time),le16(stamp.day),le32(crc),le32(data.length),le32(data.length),le16(name.length),le16(0),name,data]);
              const central = concat([le32(0x02014b50),le16(20),le16(20),le16(0x0800),le16(0),le16(stamp.time),le16(stamp.day),le32(crc),le32(data.length),le32(data.length),le16(name.length),le16(0),le16(0),le16(0),le16(0),le32(0),le32(offset),name]);
              locals.push(local); centrals.push(central); offset += local.length;
            }
            const centralData = concat(centrals);
            const end = concat([le32(0x06054b50),le16(0),le16(0),le16(entries.length),le16(entries.length),le32(centralData.length),le32(offset),le16(0)]);
            return new Blob([...locals, centralData, end], {type:'application/zip'});
          }
          function xml(value) {
            return value.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;');
          }
          async function makeDocx(title, text) {
            const lines = text.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
            const paragraphs = (lines.length ? lines : ['']).map((line, index) => `<w:p><w:r>${index === 0 ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${xml(line)}</w:t></w:r></w:p>`).join('');
            const documentXML = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${paragraphs}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr></w:body></w:document>`;
            return makeZip([
              {name:'[Content_Types].xml',data:'<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'},
              {name:'_rels/.rels',data:'<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'},
              {name:'word/document.xml',data:documentXML}
            ]);
          }
          function download(blob, name) {
            const url = URL.createObjectURL(blob); const anchor = document.createElement('a');
            anchor.href = url; anchor.download = name; document.body.appendChild(anchor); anchor.click(); anchor.remove();
            setTimeout(() => URL.revokeObjectURL(url), 1000);
          }

          $('run').onclick = async () => {
            const operation = $('operation').value; const results = [];
            $('run').disabled = true; $('results').innerHTML = ''; $('bar').style.width = '0%';
            for (let index = 0; index < selected.length; index++) {
              const file = selected[index]; $('status').textContent = `Processing ${index + 1}/${selected.length}: ${file.name}`;
              const body = new FormData(); body.append('file', file, file.name);
              try {
                const response = await fetch(`/batch/${operation}`, {method:'POST', body});
                const payload = await response.json();
                if (!response.ok) throw new Error(payload.reason || payload.message || response.statusText);
                const result = Array.isArray(payload) ? payload[0] : payload;
                if (!result) throw new Error('Empty batch response');
                results.push(result);
                $('results').insertAdjacentHTML('beforeend', `<div class="file result ${result.success ? '' : 'bad'}"><span>${escapeHTML(file.name)}</span><small>${result.success ? 'OK' : escapeHTML(result.message)}</small></div>`);
              } catch (error) {
                results.push({filename:file.name,success:false,message:error.message,text:'',raw:'',improved:''});
                $('results').insertAdjacentHTML('beforeend', `<div class="file result bad"><span>${escapeHTML(file.name)}</span><small>${escapeHTML(error.message)}</small></div>`);
              }
              $('bar').style.width = `${Math.round((index + 1) * 100 / selected.length)}%`;
            }

            const entries = [];
            for (const result of results.filter(item => item.success)) {
              const base = safeBase(result.filename);
              if (operation === 'ocr') entries.push({name:`${base}.json`,data:JSON.stringify(result,null,2)});
              if (operation === 'markdown') entries.push({name:`${base}.md`,data:`# ${base}\n\n${result.text || result.improved}\n`});
              if (operation === 'docx') entries.push({name:`${base}.docx`,data:await makeDocx(base,result.text || result.improved)});
            }
            if (entries.length) {
              $('status').textContent = `Complete: ${entries.length}/${selected.length}. Building download ZIP in this browser.`;
              const archive = await makeZip(entries);
              download(archive, `compute-${operation}-${new Date().toISOString().replace(/[:.]/g,'-')}.zip`);
              $('status').textContent = `Complete: ${entries.length}/${selected.length}. ZIP downloaded.`;
            } else {
              $('status').textContent = 'No successful result to download.';
            }
            $('run').disabled = selected.length === 0;
          };
        </script>
        </body></html>
        """#
    }
}
