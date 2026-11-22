#!/usr/bin/env node
"use strict";

// Local acceptance only. This server has no outbound client, database or credentials.
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { randomUUID } = require("node:crypto");

const web = path.resolve(__dirname, "../../web");
const modes = new Set(["off", "on", "control", "empty", "reject-assignment", "reject-exposure", "handoff"]);
const experimentId = "11111111-1111-4111-8111-111111111111";
const controlId = "22222222-2222-4222-8222-222222222222";
const treatmentId = "33333333-3333-4333-8333-333333333333";
const records = [];
const lifecycle = [];
let activeMode = "off";
let server;

function headers(type) {
  return {
    "content-type": type,
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "referrer-policy": "same-origin",
    "content-security-policy": "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'none'",
  };
}
function reply(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, headers(type));
  res.end(typeof body === "string" || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}
function modeFromRequest(req) {
  try {
    const referer = new URL(req.headers.referer);
    if (referer.host === req.headers.host && modes.has(referer.pathname.slice(1))) return referer.pathname.slice(1);
  } catch { /* direct local test request */ }
  return activeMode;
}
function lifecycleLogger() {
  return `
  ['pagehide','pageshow'].forEach(function (name) {
    window.addEventListener(name, function (event) {
      var body = JSON.stringify({name:name,persisted:event.persisted===true,path:location.pathname,at:new Date().toISOString()});
      if (navigator.sendBeacon) navigator.sendBeacon('/__qa/lifecycle', body);
      else fetch('/__qa/lifecycle',{method:'POST',body:body,keepalive:true}).catch(function(){});
    });
  });`;
}
function destination() {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Local handoff result</title>
  <style>body{font:17px/1.5 system-ui;padding:24px;max-width:1000px;margin:auto;background:#fff;color:#111}button{font:inherit;padding:10px}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style></head><body>
  <h1>Local handoff result</h1><p>The real CTA handler ran; navigation stayed on this isolated server. No App Store page was opened.</p>
  <button id="back" type="button">Back to HiAir fixture</button> <a href="/handoff?reset=1">Start a new local check</a>
  <p id="result" role="status">Waiting for the delayed conversion receipt…</p><pre id="ledger"></pre>
  <script>${lifecycleLogger()}
  document.getElementById('back').onclick=function(){history.back();};
  async function refresh(){
    var data=await fetch('/__qa/state',{cache:'no-store'}).then(function(r){return r.json();});
    var clicks=data.records.filter(function(r){return r.name==='app_store_cta.clicked'&&r.version===2;});
    var sent=clicks.filter(function(r){return r.responseFinishedAt&&!r.responseClosedEarly;});
    document.getElementById('result').textContent='Attributed clicks received: '+clicks.length+' | accepted local responses completed: '+sent.length+' | early closes: '+clicks.filter(function(r){return r.responseClosedEarly;}).length;
    document.getElementById('ledger').textContent=JSON.stringify({clicks:clicks.map(function(r){return {eventId:r.eventId,accepted:r.accepted,receivedAt:r.receivedAt,responseStartedAt:r.responseStartedAt,responseFinishedAt:r.responseFinishedAt,responseClosedEarly:r.responseClosedEarly};}),lifecycle:data.lifecycle,serverOutboundRequests:data.serverOutboundRequests},null,2);
  }
  setInterval(function(){refresh().catch(function(){});},250);refresh().catch(function(){});
  </script></body></html>`;
}
function fixtureBootstrap(mode) {
  return `<script>
  // Fixture-only configuration. No production script reads a QA flag override.
  window.GROWTH_OS_EVENTS_URL = location.origin + '/api/v1/events';
  for (var i = localStorage.length - 1; i >= 0; i--) {
    var key = localStorage.key(i);
    if (key && key.indexOf('growth_experiment:') === 0) localStorage.removeItem(key);
  }
  localStorage.setItem('hiair_growth_anon', ${JSON.stringify(mode === "control" ? "anon-golden-01" : "anon-golden-00")});
  sessionStorage.clear();
  sessionStorage.setItem('hiair_growth_session', ${JSON.stringify("local-qa-" + randomUUID())});
  document.addEventListener('click', function (event) {
    var link = event.target.closest && event.target.closest('a[href]');
    if (link && new URL(link.href, location.href).origin !== location.origin) {
      event.preventDefault();
      if (${JSON.stringify(mode)} === 'handoff' && link.matches('.js-app-store-cta[data-placement="header"]')) {
        // The real target click handler runs first. Only this fixture substitutes a local destination.
        setTimeout(function () { location.assign('/handoff-destination'); }, 50);
      }
    }
  }, true);
  ${lifecycleLogger()}
  </script>`;
}
function panel(mode) {
  return `<aside id="qa-panel" aria-label="Local measurement acceptance" style="position:fixed;z-index:99999;bottom:8px;right:8px;width:min(530px,94vw);max-height:62vh;overflow:auto;background:#fff;color:#111;border:2px solid #176945;border-radius:12px;padding:14px;font:13px/1.4 system-ui;box-shadow:0 3px 20px #0005">
  <style>#qa-panel h2, #qa-panel p, #qa-status { color: #111; }</style>
  <h2 style="font-size:17px;margin:0 0 6px">Local fixture: ${mode}</h2>
  <p>Isolated loopback sink. No Growth database or external requests. ${mode === "handoff" ? "After EXPOSED, the real header click goes to a local destination while its local response is delayed 500 ms." : "CTA navigation is disabled here."}</p>
  <nav style="display:flex;gap:8px;flex-wrap:wrap">${[...modes].map(m => `<a href="/${m}">${m}</a>`).join(" ")}</nav>
  <p><button type="button" id="qa-hide">Hide header</button> <button type="button" id="qa-show">Show header</button> <button type="button" id="qa-stop">Stop / restore</button></p>
  <p id="qa-status" role="status">Waiting for source scripts…</p>
  <pre id="qa-log" style="white-space:pre-wrap;overflow-wrap:anywhere;max-height:32vh;overflow:auto"></pre>
  </aside>
  <script>
  (function () {
    var cta = document.querySelector('.js-app-store-cta[data-placement="header"]');
    var status = document.getElementById('qa-status');
    var log = document.getElementById('qa-log');
    document.getElementById('qa-hide').onclick = function () { if (cta) cta.style.display = 'none'; };
    document.getElementById('qa-show').onclick = function () { if (cta) cta.style.removeProperty('display'); };
    document.getElementById('qa-stop').onclick = function () { if (window.HIAIR_GROWTH_EXPERIMENT) window.HIAIR_GROWTH_EXPERIMENT.stop(); };
    async function show() {
      try {
        var data = await fetch('/__qa/state', {cache:'no-store'}).then(function (r) { return r.json(); });
        var api = window.HIAIR_GROWTH_EXPERIMENT;
        var attribution = api && api.getAttribution('header', localStorage.getItem('hiair_growth_anon'), sessionStorage.getItem('hiair_growth_session'));
        status.textContent = 'Header: ' + (cta ? cta.textContent : 'missing') + ' | attribution: ' + (attribution ? 'EXPOSED' : 'none') + ' | local requests: ' + data.records.length + ' | v1: ' + data.records.filter(function (r) { return r.version === 1; }).length + ' | v2: ' + data.records.filter(function (r) { return r.version === 2; }).length;
        log.textContent = data.records.slice(-8).map(function (r) { return [r.sequence, r.method, r.name || 'config', r.version ? 'v' + r.version : '', r.placement || '', r.accepted === undefined ? '' : (r.accepted ? 'accepted' : 'REJECTED')].join(' '); }).join('\\n');
      } catch (_) { status.textContent = 'Local fixture unavailable'; }
    }
    setInterval(show, 250); show();
  })();
  </script>`;
}

// Compile the emitted browser scripts, not merely this template-producing file.
for (const mode of modes) {
  for (const match of (fixtureBootstrap(mode) + panel(mode) + destination()).matchAll(/<script>([\s\S]*?)<\/script>/g)) {
    new vm.Script(match[1], { filename: "local-fixture-" + mode });
  }
}

server = http.createServer(async (req, res) => {
  const expectedHost = "127.0.0.1:" + server.address().port;
  if (req.headers.host !== expectedHost || req.headers.origin && req.headers.origin !== "http://" + expectedHost) return reply(res, 403, { error: "local_origin_required" });
  let url;
  try { url = new URL(req.url, "http://" + expectedHost); } catch { return reply(res, 400, { error: "invalid_url" }); }
  if (req.method === "GET" && url.pathname === "/__qa/state") return reply(res, 200, { mode: activeMode, records, lifecycle, serverOutboundRequests: 0 });
  if (req.method === "GET" && url.pathname === "/handoff-destination") return reply(res, 200, destination(), "text/html; charset=utf-8");
  if (req.method === "POST" && url.pathname === "/__qa/lifecycle") {
    let body="";
    try {
      for await(const chunk of req) {body+=chunk;if(Buffer.byteLength(body)>2048)return reply(res,413,{ok:false});}
      const event=JSON.parse(body);
      if (!['pagehide','pageshow'].includes(event.name)||typeof event.persisted!=="boolean"||typeof event.path!=="string"||event.path.length>80||typeof event.at!=="string")return reply(res,400,{ok:false});
      lifecycle.push({name:event.name,persisted:event.persisted,path:event.path,at:event.at,receivedAt:new Date().toISOString()});
      return reply(res,200,{ok:true});
    }catch{return reply(res,400,{ok:false});}
  }
  if (req.method === "GET" && url.pathname === "/api/v1/experiments/active") {
    const mode = modeFromRequest(req);
    records.push({ sequence: records.length + 1, method: "GET", name: "config", mode, query: Object.fromEntries(url.searchParams) });
    return reply(res, 200, { experiments: mode === "empty" ? [] : [{
      id: experimentId, assignment_version: "v1", surface: "website", placement: "header",
      allocation: [
        { variant_id: controlId, role: "CONTROL", weight: 0.5, public_config: {} },
        { variant_id: treatmentId, role: "TREATMENT", weight: 0.5, public_config: { cta_copy: "Get HiAir on the App Store" } },
      ],
    }] });
  }
  if (req.method === "POST" && url.pathname === "/api/v1/events") {
    let body = "";
    try {
      for await (const chunk of req) {
        body += chunk;
        if (Buffer.byteLength(body) > 8192) return reply(res, 413, { ok: false, stored: false, duplicate: false });
      }
      const event = JSON.parse(body), mode = modeFromRequest(req);
      if (!event || event.productSlug !== "hiair" || typeof event.name !== "string" || typeof event.event_id !== "string" || event.event_id.length > 200 || typeof event.anonymousId !== "string" || event.anonymousId.length > 128) return reply(res, 400, { ok: false, stored: false, duplicate: false });
      const accepted = !(mode === "reject-assignment" && event.name === "experiment.assigned") && !(mode === "reject-exposure" && event.name === "experiment.exposed");
      const record={ sequence: records.length + 1, method: "POST", mode, name: event.name, version: event.event_version, placement: event.properties?.placement, accepted, eventId: event.event_id, event, receivedAt:new Date().toISOString() };
      records.push(record);
      if(mode === "handoff" && event.name === "app_store_cta.clicked" && event.event_version === 2) {
        record.delayMs=500;
        res.once("finish",()=>{record.responseFinishedAt=new Date().toISOString();});
        res.once("close",()=>{if(!res.writableFinished)record.responseClosedEarly=true;});
        await new Promise(resolve=>setTimeout(resolve,500));
        record.responseStartedAt=new Date().toISOString();
      }
      return reply(res, 202, { ok: accepted, stored: accepted, duplicate: false, request_id: randomUUID() });
    } catch { return reply(res, 400, { ok: false, stored: false, duplicate: false }); }
  }
  if (req.method !== "GET") return reply(res, 405, { error: "method" });
  const mode = url.pathname === "/" ? "off" : url.pathname.slice(1);
  if (modes.has(mode)) {
    if (mode !== "handoff" || activeMode !== "handoff" || url.searchParams.get("reset") === "1") { records.length = 0; lifecycle.length = 0; }
    activeMode = mode;
    let html = fs.readFileSync(path.join(web, "index.html"), "utf8");
    html = html.replace("<head>", "<head>" + fixtureBootstrap(mode));
    // Only the local fixture chooses the ON copy of main; the tracked source remains OFF.
    html = html.replace(/src="\/js\/main\.js"/, `src="/js/main.js?fixture=${mode}"`);
    html = html.replace("</body>", panel(mode) + "</body>");
    return reply(res, 200, html, "text/html; charset=utf-8");
  }
  let decoded;
  try { decoded = decodeURIComponent(url.pathname); } catch { return reply(res, 400, { error: "invalid_path" }); }
  const filename = path.resolve(web, "." + decoded);
  if (!filename.startsWith(web + path.sep)) return reply(res, 403, { error: "outside_fixture" });
  try {
    if (!fs.statSync(filename).isFile()) return reply(res, 404, { error: "missing" });
    if (!fs.realpathSync(filename).startsWith(fs.realpathSync(web) + path.sep)) return reply(res, 403, { error: "outside_fixture" });
    let body = fs.readFileSync(filename);
    if (decoded === "/js/main.js" && modes.has(url.searchParams.get("fixture")) && url.searchParams.get("fixture") !== "off") {
      const text = body.toString("utf8"), literal = "var HIAIR_EXPERIMENTS_ENABLED = false;";
      if (text.split(literal).length !== 2) return reply(res, 500, { error: "flag_literal_not_unique" });
      body = text.replace(literal, "var HIAIR_EXPERIMENTS_ENABLED = true;");
    }
    const ext = path.extname(filename);
    return reply(res, 200, body, ({ ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".svg": "image/svg+xml", ".png": "image/png", ".webp": "image/webp", ".woff2": "font/woff2" })[ext] || "application/octet-stream");
  } catch { return reply(res, 404, { error: "missing" }); }
});
server.listen(0, "127.0.0.1", () => {
  const origin = "http://127.0.0.1:" + server.address().port;
  console.log(JSON.stringify({ purpose: "ISOLATED_LOCAL_ACCEPTANCE_ONLY", origin, urls: [...modes].map(mode => origin + "/" + mode), productionWrites: 0 }));
});
function close() { server.close(); server.closeAllConnections(); }
process.once("SIGINT", close);
process.once("SIGTERM", close);
