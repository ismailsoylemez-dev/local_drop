import '../core/constants.dart';

/// PC tarayıcısında açılan tek dosya arayüz. Harici kaynak yok; kullanıcı
/// verisi yalnız `textContent` ile basılır (innerHTML kullanılmaz).
const String webUiHtml =
    r'''<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>Local Drop</title>
<style>
:root {
  --bg: #f4f7f7; --card: #ffffff; --text: #182222; --muted: #5b6b6b;
  --accent: #00796b; --accent-text: #ffffff; --border: #d5dfde;
  --danger: #b3261e; --ok: #2e7d32; --drop: #e0f2f1;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #101616; --card: #182121; --text: #e3eceb; --muted: #9db0ae;
    --accent: #4db6ac; --accent-text: #00201c; --border: #2b3a39;
    --danger: #f2b8b5; --ok: #a5d6a7; --drop: #1f3331;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 16px; background: var(--bg); color: var(--text);
  font: 15px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
main { max-width: 760px; margin: 0 auto; display: grid; gap: 16px; }
h1 { font-size: 22px; margin: 0; }
h2 { font-size: 16px; margin: 0 0 12px; }
section {
  background: var(--card); border: 1px solid var(--border);
  border-radius: 12px; padding: 16px;
}
button, .btn {
  font: inherit; border: 1px solid var(--border); background: transparent;
  color: var(--text); border-radius: 8px; padding: 6px 12px; cursor: pointer;
  text-decoration: none; display: inline-block; white-space: nowrap;
}
button.primary { background: var(--accent); color: var(--accent-text); border-color: var(--accent); }
button.danger { color: var(--danger); border-color: var(--danger); }
button:disabled { opacity: .5; cursor: default; }
.muted { color: var(--muted); font-size: 13px; }
.hidden { display: none !important; }
#banner {
  border-color: var(--danger); color: var(--danger);
  display: flex; gap: 12px; align-items: center; justify-content: space-between;
}
#drop {
  border: 2px dashed var(--border); border-radius: 12px; padding: 24px 12px;
  text-align: center; display: grid; gap: 8px; justify-items: center;
}
#drop.over { background: var(--drop); border-color: var(--accent); }
ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.row {
  display: grid; grid-template-columns: 1fr auto; gap: 4px 12px;
  align-items: center; padding: 8px 0; border-top: 1px solid var(--border);
}
.row:first-child { border-top: 0; }
.name { overflow-wrap: anywhere; }
.actions { display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
progress { width: 100%; grid-column: 1 / -1; height: 8px; accent-color: var(--accent); }
.ok { color: var(--ok); }
.err { color: var(--danger); }
textarea {
  width: 100%; min-height: 110px; resize: vertical; font: inherit;
  color: var(--text); background: transparent; border: 1px solid var(--border);
  border-radius: 8px; padding: 8px;
}
.bar { display: flex; gap: 12px; align-items: center; justify-content: space-between; margin-top: 8px; flex-wrap: wrap; }
@media (max-width: 420px) {
  body { padding: 8px; }
  section { padding: 12px; }
  .row { grid-template-columns: 1fr; }
  .actions { justify-content: flex-start; }
}
</style>
</head>
<body>
<main>
  <h1>Local Drop</h1>

  <section id="banner" class="hidden" role="alert">
    <span id="bannerText"></span>
    <button id="bannerRetry" class="hidden">Tekrar dene</button>
  </section>

  <section>
    <h2>Telefona dosya gönder</h2>
    <div id="drop">
      <span>Dosyaları buraya sürükleyin</span>
      <span class="muted">veya</span>
      <button id="pick" class="primary">Dosya seç</button>
      <input id="fileInput" type="file" multiple class="hidden">
    </div>
    <ul id="uploads"></ul>
  </section>

  <section>
    <div class="bar" style="margin:0 0 12px">
      <h2 style="margin:0">Telefondaki dosyalar</h2>
      <button id="refresh">Yenile</button>
    </div>
    <ul id="files"></ul>
    <p id="empty" class="muted hidden">Henüz dosya yok.</p>
  </section>

  <section>
    <h2>Telefona metin gönder</h2>
    <textarea id="text" placeholder="Bağlantı, not, kod…"></textarea>
    <div class="bar">
      <span id="textInfo" class="muted"></span>
      <button id="sendText" class="primary">Telefona gönder</button>
    </div>
  </section>
</main>
<script>
(() => {
'use strict';
const MAX_TEXT = '''
    '${AppConstants.maxTextBytes}'
    r''';
const REFRESH_MS = '''
    '${AppConstants.webListRefreshMs}'
    r''';
const MSG_AUTH = 'Bağlantı süresi doldu, QR\'ı tekrar okutun.';
const MSG_NET = 'Telefona ulaşılamadı.';

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};

// Token cookie'ye alındı; adres çubuğunda/geçmişte kalmasın.
if (location.search) history.replaceState(null, '', location.pathname);

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let v = bytes, i = 0;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return v.toFixed(1).replace('.', ',') + ' ' + units[i];
}

function formatEta(sec) {
  if (!isFinite(sec)) return '—';
  sec = Math.max(0, Math.round(sec));
  const m = Math.floor(sec / 60), s = sec % 60;
  return m > 0 ? m + ' dk ' + s + ' sn' : s + ' sn';
}

let authLost = false;
function showBanner(text, retry) {
  $('bannerText').textContent = text;
  const btn = $('bannerRetry');
  btn.classList.toggle('hidden', !retry);
  btn.onclick = retry ? () => { hideBanner(); retry(); } : null;
  $('banner').classList.remove('hidden');
}
function hideBanner() { $('banner').classList.add('hidden'); }
function onAuthLost() {
  authLost = true;
  showBanner(MSG_AUTH, null);
}

async function errorText(res, fallback) {
  try { const j = await res.json(); return j.error || fallback; }
  catch (_) { return fallback; }
}

// ---- Dosya listesi ----
let pendingDelete = null;

async function loadFiles() {
  if (authLost) return;
  let res;
  try {
    res = await fetch('/api/files', { cache: 'no-store', credentials: 'same-origin' });
  } catch (_) {
    showBanner(MSG_NET, loadFiles);
    return;
  }
  if (res.status === 401) return onAuthLost();
  if (!res.ok) return showBanner(await errorText(res, 'Liste alınamadı.'), loadFiles);
  hideBanner();
  renderFiles(await res.json());
}

function renderFiles(files) {
  const list = $('files');
  list.replaceChildren();
  $('empty').classList.toggle('hidden', files.length > 0);
  for (const f of files) {
    const li = el('li', 'row');
    const info = el('div');
    info.append(el('div', 'name', f.name), el('div', 'muted', formatSize(f.size)));
    const actions = el('div', 'actions');
    const dl = el('a', 'btn', 'İndir');
    dl.href = '/api/download/' + encodeURIComponent(f.name);
    dl.setAttribute('download', f.name);
    actions.append(dl);
    if (pendingDelete === f.name) {
      const yes = el('button', 'danger', 'Emin misin?');
      yes.onclick = () => deleteFile(f.name);
      const no = el('button', '', 'Vazgeç');
      no.onclick = () => { pendingDelete = null; loadFiles(); };
      actions.append(yes, no);
    } else {
      const del = el('button', 'danger', 'Sil');
      del.onclick = () => { pendingDelete = f.name; renderFiles(files); };
      actions.append(del);
    }
    li.append(info, actions);
    list.append(li);
  }
}

async function deleteFile(name) {
  pendingDelete = null;
  let res;
  try {
    res = await fetch('/api/files/' + encodeURIComponent(name), {
      method: 'DELETE', credentials: 'same-origin',
    });
  } catch (_) {
    showBanner(MSG_NET, () => deleteFile(name));
    return;
  }
  if (res.status === 401) return onAuthLost();
  if (!res.ok && res.status !== 404) showBanner(await errorText(res, 'Silinemedi.'), null);
  loadFiles();
}

// ---- Yükleme ----
function upload(file, row) {
  if (!row) {
    row = el('li', 'row');
    $('uploads').append(row);
  }
  const name = el('div', 'name', file.name);
  const status = el('div', 'muted', 'Bekliyor…');
  const bar = el('progress');
  bar.max = file.size || 1;
  bar.value = 0;
  row.replaceChildren(name, status, bar);

  const form = new FormData();
  form.append('file', file, file.name);
  const xhr = new XMLHttpRequest();
  const started = performance.now();

  xhr.upload.onprogress = (e) => {
    if (!e.lengthComputable) return;
    bar.max = e.total;
    bar.value = e.loaded;
    const secs = (performance.now() - started) / 1000;
    const speed = secs > 0 ? e.loaded / secs : 0;
    const pct = Math.floor((e.loaded / e.total) * 100);
    status.textContent = pct + '% · ' + formatSize(Math.round(speed)) + '/s · kalan '
      + formatEta(speed > 0 ? (e.total - e.loaded) / speed : Infinity);
  };
  const fail = (text, retryable) => {
    status.className = 'err';
    status.textContent = text;
    bar.remove();
    if (retryable) {
      const retry = el('button', '', 'Tekrar dene');
      retry.onclick = () => upload(file, row);
      row.append(retry);
    }
  };
  xhr.onload = async () => {
    if (xhr.status === 200) {
      bar.value = bar.max;
      status.className = 'ok';
      status.textContent = 'Tamamlandı · ' + formatSize(file.size);
      loadFiles();
    } else if (xhr.status === 401) {
      fail(MSG_AUTH, false);
      onAuthLost();
    } else if (xhr.status === 413) {
      fail('Dosya çok büyük.', false);
    } else {
      let msg = 'Yükleme başarısız (' + xhr.status + ').';
      try { msg = JSON.parse(xhr.responseText).error || msg; } catch (_) {}
      fail(msg, true);
    }
  };
  xhr.onerror = () => fail('Ağ hatası.', true);
  xhr.open('POST', '/api/upload');
  xhr.send(form);
}

function uploadAll(fileList) {
  if (authLost) return onAuthLost();
  for (const f of fileList) upload(f);
}

const drop = $('drop');
['dragenter', 'dragover'].forEach((t) => drop.addEventListener(t, (e) => {
  e.preventDefault();
  drop.classList.add('over');
}));
['dragleave', 'drop'].forEach((t) => drop.addEventListener(t, (e) => {
  e.preventDefault();
  drop.classList.remove('over');
}));
drop.addEventListener('drop', (e) => {
  if (e.dataTransfer && e.dataTransfer.files.length) uploadAll(e.dataTransfer.files);
});
// Bırakma alanı dışına düşen dosya tarayıcıda açılmasın.
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', (e) => e.preventDefault());
$('pick').onclick = () => $('fileInput').click();
$('fileInput').onchange = (e) => {
  uploadAll(e.target.files);
  e.target.value = '';
};

// ---- Metin ----
const encoder = new TextEncoder();
const textArea = $('text');
const textInfo = $('textInfo');
function textBytes() { return encoder.encode(textArea.value).length; }
function updateTextInfo() {
  const n = textBytes();
  textInfo.className = n > MAX_TEXT ? 'err' : 'muted';
  textInfo.textContent = n > MAX_TEXT
    ? 'Metin çok uzun (' + formatSize(n) + ' / ' + formatSize(MAX_TEXT) + ')'
    : '';
}
textArea.addEventListener('input', updateTextInfo);

$('sendText').onclick = async () => {
  const text = textArea.value;
  if (!text) return;
  if (textBytes() > MAX_TEXT) return updateTextInfo();
  const btn = $('sendText');
  btn.disabled = true;
  try {
    const res = await fetch('/api/text', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
    });
    if (res.status === 401) return onAuthLost();
    if (res.ok) {
      textArea.value = '';
      textInfo.className = 'ok';
      textInfo.textContent = 'Gönderildi ✓';
    } else {
      textInfo.className = 'err';
      textInfo.textContent = await errorText(res, 'Gönderilemedi.');
    }
  } catch (_) {
    showBanner(MSG_NET, () => $('sendText').click());
  } finally {
    btn.disabled = false;
  }
};

$('refresh').onclick = loadFiles;
setInterval(() => {
  if (document.visibilityState === 'visible' && pendingDelete === null) loadFiles();
}, REFRESH_MS);
loadFiles();
})();
</script>
</body>
</html>
''';
