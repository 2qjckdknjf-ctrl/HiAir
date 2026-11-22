"use strict";

const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");
const { spawn } = require("node:child_process");
const { once } = require("node:events");

const EXPERIMENT = "11111111-1111-4111-8111-111111111111";
const CONTROL = "22222222-2222-4222-8222-222222222222";
const TREATMENT = "33333333-3333-4333-8333-333333333333";
const ORIGIN = "http://127.0.0.1:49151";
const CTA_COPY = "Get HiAir on the App Store";
const html = fs.readFileSync(path.join(__dirname, "../index.html"), "utf8");
const loadedScripts = [...html.matchAll(/<script[^>]+src="([^"]+)"[^>]*>/g)].map(m => m[1]);
const attrs = text => Object.fromEntries([...text.matchAll(/([\w-]+)="([^"]*)"/g)].map(m => [m[1], m[2].replaceAll("&amp;", "&")]));
const tickPromises = async () => { for (let i = 0; i < 5; i++) await new Promise(resolve => setImmediate(resolve)); };

function latch() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function storage(initial = {}) {
  const values = new Map(Object.entries(initial));
  return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, String(value)), removeItem: key => values.delete(key), values };
}
function ack(accepted = true) {
  return new Response(JSON.stringify({ ok: accepted, stored: accepted, duplicate: false, request_id: "local-fixture" }), { status: 202, headers: { "content-type": "application/json" } });
}
function config(overrides = {}) {
  return { experiments: [{ id: EXPERIMENT, assignment_version: "v1", surface: "website", placement: "header", allocation: [
    { variant_id: CONTROL, role: "CONTROL", weight: 0.5, public_config: {} },
    { variant_id: TREATMENT, role: "TREATMENT", weight: 0.5, public_config: { cta_copy: CTA_COPY } },
  ], ...overrides }] };
}

class Element {
  constructor(attributes, text) { this.attributes = attributes; this.textContent = text; this.listeners = new Map(); this.style = {}; this.isConnected = true; }
  getAttribute(name) { return this.attributes[name] ?? null; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  removeAttribute(name) { delete this.attributes[name]; }
  addEventListener(name, fn) { const handlers = this.listeners.get(name) || new Set(); handlers.add(fn); this.listeners.set(name, handlers); }
  removeEventListener(name, fn) { this.listeners.get(name)?.delete(fn); }
  dispatch(name) { for (const fn of [...(this.listeners.get(name) || [])]) fn({ type: name, target: this, preventDefault() {} }); }
  getBoundingClientRect() { return { top: 0, left: 0, width: 120, height: 44, bottom: 44, right: 120 }; }
  contains(other) { return other === this; }
  remove() { this.isConnected = false; }
}

// Runs the actual HTML script list, with the same main click handler and helper objects.
// The fetch seam records locally and throws for ANY address outside the isolated sink.
function page(options = {}) {
  let now = Date.UTC(2026, 10, 22, 12), timerId = 0;
  const timers = new Map(), canceled = new Set(), requests = [], observers = [], mutationObservers = [], windowListeners = new Map();
  const elements = [...html.matchAll(/<a\b([^>]*\bclass="[^"]*js-app-store-cta[^"]*"[^>]*)>([\s\S]*?)<\/a>/g)]
    .map(m => new Element(attrs(m[1]), m[2].replace(/<[^>]+>/g, "").trim()));
  assert.equal(elements.length, 7, "fixture reads all actual homepage CTA elements");
  const header = elements.find(el => el.getAttribute("data-placement") === "header");
  const localStorage = options.storage || storage({ hiair_growth_anon: options.anonymousId || "anon-golden-00" });
  const sessionStorage = storage({ hiair_growth_session: "local-session" });
  const docListeners = new Map();
  function select(selector) {
    if (!selector.startsWith(".js-app-store-cta")) return [];
    const placement = /\[data-placement=["']?([^\]"']+)/.exec(selector)?.[1];
    return elements.filter(el => !placement || el.getAttribute("data-placement") === placement);
  }
  const document = {
    documentElement: { lang: "en", contains: el => el.isConnected }, hidden: false, visibilityState: "visible",
    querySelector: selector => select(selector)[0] || null, querySelectorAll: select, getElementById: () => null,
    addEventListener(name, fn) { const set = docListeners.get(name) || new Set(); set.add(fn); docListeners.set(name, set); },
    removeEventListener(name, fn) { docListeners.get(name)?.delete(fn); },
  };
  const schedule = (fn, ms, repeat = 0) => { const id = ++timerId; timers.set(id, { fn, at: now + Number(ms || 0), repeat }); return id; };
  const cancel = id => { timers.delete(id); canceled.add(id); };
  class ClockDate extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
  class Observer {
    constructor(callback, config) { this.callback = callback; this.config = config; this.targets = new Set(); observers.push(this); }
    observe(target) { this.targets.add(target); }
    unobserve(target) { this.targets.delete(target); }
    disconnect() { this.targets.clear(); }
  }
  class MutationObserver {
    constructor(callback) { this.callback = callback; this.active = false; mutationObservers.push(this); }
    observe() { this.active = true; }
    disconnect() { this.active = false; }
  }
  const fetch = async (address, init = {}) => {
    const url = new URL(address, ORIGIN);
    assert.equal(url.origin, ORIGIN, "fixture MUST NOT contact production or localhost:3001");
    const body = init.body ? JSON.parse(init.body) : null;
    const call = { url: url.href, method: init.method || "GET", body, at: now, keepalive: init.keepalive === true, signal: init.signal };
    requests.push(call);
    if (body) {
      assert.ok(Buffer.byteLength(init.body) <= 8192);
      assert.ok(body.event_id.length <= 200);
      assert.ok(body.anonymousId.length <= 128);
      assert.equal(url.pathname, "/api/v1/events");
    } else {
      assert.equal(url.pathname, "/api/v1/experiments/active");
      assert.equal(url.searchParams.get("product"), "hiair");
      assert.equal(url.searchParams.get("surface"), "website");
      assert.equal(url.searchParams.get("placement"), "header");
    }
    if (options.respond) { const response = await options.respond(call); if (response) return response; }
    return body ? ack() : new Response(JSON.stringify(options.config || config()), { status: 200 });
  };
  const sandbox = {
    GROWTH_OS_EVENTS_URL: ORIGIN + "/api/v1/events", document, localStorage, sessionStorage, fetch,
    location: { origin: ORIGIN, hostname: "127.0.0.1", pathname: "/", href: ORIGIN + "/", search: "" },
    crypto: options.crypto === undefined ? webcrypto : options.crypto,
    TextEncoder, TextDecoder, URL, URLSearchParams, Response, AbortController, DOMException,
    Date: ClockDate, performance: { now: () => now }, console,
    setTimeout: (fn, ms) => schedule(fn, ms), clearTimeout: cancel,
    setInterval: (fn, ms) => schedule(fn, ms, Number(ms)), clearInterval: cancel,
    IntersectionObserver: options.noObserver ? undefined : Observer, MutationObserver,
    matchMedia: () => ({ matches: true }), innerWidth: 1280, innerHeight: 800,
    addEventListener(name, fn) { const set = windowListeners.get(name) || new Set(); set.add(fn); windowListeners.set(name, set); },
    removeEventListener(name, fn) { windowListeners.get(name)?.delete(fn); },
  };
  sandbox.window = sandbox; sandbox.globalThis = sandbox;
  const context = vm.createContext(sandbox);
  let started = Promise.resolve();
  for (const relative of loadedScripts) {
    assert.match(relative, /^\/js\/[a-z-]+\.js$/);
    let source = fs.readFileSync(path.join(__dirname, path.basename(relative)), "utf8");
    if (relative === "/js/main.js") {
      const api = sandbox.HIAIR_GROWTH_EXPERIMENT;
      assert.ok(api, "actual HTML must load the runtime before main");
      const realStart = api.start;
      api.start = function (input) { started = realStart.call(api, input); return started; };
      if (options.enabled) {
        const literal = "var HIAIR_EXPERIMENTS_ENABLED = false;";
        assert.equal(source.split(literal).length, 2);
        source = source.replace(literal, "var HIAIR_EXPERIMENTS_ENABLED = true;");
      }
    }
    vm.runInContext(source, context, { filename: relative });
  }
  const api = sandbox.HIAIR_GROWTH_EXPERIMENT;
  return {
    api, header, elements, requests, sandbox, document, localStorage, sessionStorage,
    ready: async () => { const result = await started; await tickPromises(); return result; },
    events: name => requests.filter(r => r.body && (!name || r.body.name === name)).map(r => r.body),
    async advance(ms) {
      const end = now + ms;
      for (let n = 0; n < 1000; n++) {
        const next = [...timers.entries()].filter(([, t]) => t.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
        if (!next) { now = end; await tickPromises(); return; }
        const [id, timer] = next; timers.delete(id); now = timer.at; timer.fn(); await tickPromises();
        if (timer.repeat && !canceled.has(id)) timers.set(id, { ...timer, at: now + timer.repeat });
      }
      throw Error("unbounded fixture timer loop");
    },
    intersect(ratio) {
      for (const observer of observers) if (observer.targets.has(header)) observer.callback([{ target: header, intersectionRatio: ratio, isIntersecting: ratio > 0, time: now }], observer);
    },
    visibility(hidden) { document.hidden = hidden; document.visibilityState = hidden ? "hidden" : "visible"; for (const fn of docListeners.get("visibilitychange") || []) fn(); },
    pagehide(persisted) { for (const fn of [...(windowListeners.get("pagehide") || [])]) fn({ type: "pagehide", persisted: persisted === true }); },
    close() { api.stop(); timers.clear(); },
  };
}

test("actual homepage with default OFF preserves seven v1 placement views, CTA links and aliases without experiment requests", async () => {
  const p = page();
  try {
    await p.ready();
    assert.equal(p.header.textContent, "Download");
    assert.equal(p.requests.filter(r => r.method === "GET").length, 0);
    const views = p.events("app_store_cta.viewed");
    assert.equal(views.length, 7);
    assert.equal(new Set(views.map(e => e.properties.placement)).size, 7);
    assert.ok(views.every(e => e.event_version === 1 && !e.properties.experiment_id));
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked").length, 1);
    assert.equal(p.events("ios_download_click").length, 1);
    assert.equal(p.events("header_download_click").length, 1);
    assert.ok(p.events().every(e => e.event_version === 1));
    assert.match(p.header.getAttribute("href"), /^https:\/\/apps\.apple\.com\/us\/app\/hiair\/id6773610034\?/);
    assert.equal(p.header.getAttribute("target"), "_blank");
  } finally { p.close(); }
});

test("one stationary header exposure enables exactly one contextual v2 click, distinct from an earlier v1 click", async () => {
  const p = page({ enabled: true });
  try {
    await p.ready();
    assert.equal(p.events("experiment.assigned").length, 1);
    assert.equal(p.header.textContent, CTA_COPY);
    assert.equal(p.events("app_store_cta.viewed").length, 7);
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
    p.intersect(0.5);
    await p.advance(999); assert.equal(p.events("experiment.exposed").length, 0);
    await p.advance(1); assert.equal(p.events("experiment.exposed").length, 1);
    const context = p.api.getAttribution("header", "anon-golden-00", "local-session");
    assert.equal(context.experimentId, EXPERIMENT);
    p.header.dispatch("click"); await tickPromises();
    const clicks = p.events("app_store_cta.clicked");
    assert.equal(clicks.length, 2, "one event per action, no v1 plus v2 duplicate");
    assert.equal(clicks[1].event_version, 2);
    assert.notEqual(clicks[0].event_id, clicks[1].event_id, "early v1 must not deduplicate away the later attributed click");
    assert.equal(clicks[1].properties.experiment_id, EXPERIMENT);
    assert.equal(clicks[1].properties.variant_id, TREATMENT);
    assert.equal(clicks[1].properties.assignment_version, "v1");
    assert.equal(clicks[1].properties.placement, "header");
    assert.equal(p.events("ios_download_click").length, 2);
    assert.equal(p.events("header_download_click").length, 2);
    const other = p.elements.find(el => el.getAttribute("data-placement") === "hero");
    other.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked").at(-1).event_version, 1);
    p.api.stop();
    assert.equal(p.header.textContent, "Download");
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
  } finally { p.close(); }
});

test("a visibility interruption restarts the full exposure interval and a hidden document never qualifies", async () => {
  const p = page({ enabled: true });
  try {
    await p.ready(); p.intersect(0.8); await p.advance(700); p.intersect(0.49); await p.advance(1000);
    assert.equal(p.events("experiment.exposed").length, 0);
    p.intersect(0.8); await p.advance(700); p.visibility(true); await p.advance(1000);
    assert.equal(p.events("experiment.exposed").length, 0);
    p.visibility(false); p.intersect(0.8); await p.advance(999);
    assert.equal(p.events("experiment.exposed").length, 0);
    await p.advance(1); assert.equal(p.events("experiment.exposed").length, 1);
  } finally { p.close(); }
});

test("assignment must receive an accepted JSON acknowledgement before treatment; stopping ignores its late reply", async () => {
  const gate = latch(), entered = latch();
  const p = page({ enabled: true, respond: call => {
    if (call.body?.name === "experiment.assigned") { entered.resolve(); return gate.promise; }
  } });
  try {
    await Promise.race([entered.promise, p.ready().then(() => { throw Error("assignment was never requested"); })]);
    assert.equal(p.header.textContent, "Download");
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
    p.api.stop(); gate.resolve(ack()); await p.ready();
    assert.equal(p.header.textContent, "Download");
    p.intersect(1); await p.advance(2000);
    assert.equal(p.events("experiment.exposed").length, 0);
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
  } finally { gate.resolve(ack()); p.close(); }
});

for (const [name, options] of [
  ["empty config", { config: { experiments: [] } }],
  ["wrong placement", { config: config({ placement: "hero" }) }],
  ["missing Web Crypto", { crypto: {} }],
  ["missing IntersectionObserver", { noObserver: true }],
  ["assignment rejected despite HTTP202", { respond: call => call.body?.name === "experiment.assigned" ? ack(false) : undefined }],
  ["assignment malformed acknowledgement", { respond: call => call.body?.name === "experiment.assigned" ? new Response("{}", { status: 200 }) : undefined }],
]) {
  test(name + " leaves CONTROL and ordinary tracking functional", async () => {
    const p = page({ enabled: true, ...options });
    try {
      await p.ready();
      assert.equal(p.header.textContent, "Download");
      p.intersect(1); await p.advance(1100);
      assert.equal(p.events("experiment.exposed").length, 0);
      p.header.dispatch("click"); await tickPromises();
      assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
      assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
    } finally { p.close(); }
  });
}

test("a rejected exposure cannot authorize a click or leave treatment applied", async () => {
  const p = page({ enabled: true, respond: call => call.body?.name === "experiment.exposed" ? ack(false) : undefined });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000);
    assert.equal(p.events("experiment.exposed").length, 1);
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
    assert.equal(p.header.textContent, "Download");
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
  } finally { p.close(); }
});

test("the CONTROL allocation records its real exposure while retaining the exact original header", async () => {
  const p = page({ enabled: true, anonymousId: "anon-golden-01" });
  try {
    assert.equal((await p.ready()).variant, "CONTROL");
    assert.equal(p.header.textContent, "Download");
    p.intersect(1); await p.advance(1000); p.header.dispatch("click"); await tickPromises();
    const click = p.events("app_store_cta.clicked")[0];
    assert.equal(click.event_version, 2);
    assert.equal(click.properties.variant_id, CONTROL);
    assert.equal(p.header.textContent, "Download");
  } finally { p.close(); }
});

test("denied storage keeps the CTA usable and never creates an assignment or exposure", async () => {
  const p = page({ enabled: true, storage: { getItem() { throw Error("blocked"); }, setItem() { throw Error("blocked"); } } });
  try {
    await p.ready(); p.intersect(1); await p.advance(1100);
    assert.equal(p.header.textContent, "Download");
    assert.equal(p.events("experiment.assigned").length, 0);
    assert.equal(p.events("experiment.exposed").length, 0);
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
  } finally { p.close(); }
});

test("changing identity removes attribution and an old sticky entry cannot assign the new visitor", async () => {
  const p = page({ enabled: true });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000);
    assert.ok(p.api.getAttribution("header", "anon-golden-00", "local-session"));
    p.localStorage.setItem("hiair_growth_anon", "anon-golden-01");
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
    assert.equal(p.header.textContent, "Download");
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
    const reloaded = page({ enabled: true, storage: p.localStorage });
    try {
      assert.equal((await reloaded.ready()).variant, "CONTROL");
      assert.equal(reloaded.header.textContent, "Download");
      assert.equal(reloaded.events("experiment.assigned")[0].anonymousId, "anon-golden-01");
      assert.equal(reloaded.events("experiment.assigned")[0].properties.variant_id, CONTROL);
    } finally { reloaded.close(); }
  } finally { p.close(); }
});

test("pending exposure never tags clicks, and its late receipt cannot revive a stopped runtime", async () => {
  const gate = latch();
  const p = page({ enabled: true, respond: call => call.body?.name === "experiment.exposed" ? gate.promise : undefined });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000);
    assert.equal(p.events("experiment.exposed").length, 1);
    p.header.dispatch("click"); await tickPromises();
    assert.equal(p.events("app_store_cta.clicked")[0].event_version, 1);
    p.api.stop(); gate.resolve(ack()); await tickPromises();
    assert.equal(p.header.textContent, "Download");
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
  } finally { gate.resolve(ack()); p.close(); }
});

test("bfcache pagehide keeps treatment and does not abort the attributed click", async () => {
  const gate = latch();
  const p = page({ enabled: true, respond: call => call.body?.name === "app_store_cta.clicked" && call.body.event_version === 2 ? gate.promise : undefined });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000);
    assert.equal(p.header.textContent, CTA_COPY);
    p.header.dispatch("click");
    p.pagehide(true);
    await tickPromises();
    const click = p.requests.filter(r => r.body?.name === "app_store_cta.clicked" && r.body.event_version === 2).at(-1);
    assert.ok(click, "attributed click must leave the page");
    assert.equal(click.keepalive, true);
    assert.equal(click.signal.aborted, false);
    assert.equal(p.header.textContent, CTA_COPY);
    assert.ok(p.api.getAttribution("header", "anon-golden-00", "local-session"));
    gate.resolve(ack());
    await tickPromises();
    assert.equal(p.events("app_store_cta.clicked").filter(e => e.event_version === 2).length, 1);
    assert.equal(p.header.textContent, CTA_COPY);
    assert.ok(p.api.getAttribution("header", "anon-golden-00", "local-session"));
  } finally { gate.resolve(ack()); p.close(); }
});

test("a discarding pagehide still delivers the in-flight attributed click", async () => {
  const gate = latch();
  const p = page({ enabled: true, respond: call => call.body?.name === "app_store_cta.clicked" && call.body.event_version === 2 ? gate.promise : undefined });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000);
    p.header.dispatch("click");
    await tickPromises();
    p.pagehide(false);
    const click = p.requests.filter(r => r.body?.name === "app_store_cta.clicked" && r.body.event_version === 2).at(-1);
    assert.ok(click);
    assert.equal(click.keepalive, true);
    assert.equal(click.signal.aborted, false);
    gate.resolve(ack());
    await tickPromises();
    assert.equal(p.events("app_store_cta.clicked").filter(e => e.event_version === 2).length, 1);
    assert.equal(p.events("app_store_cta.clicked").filter(e => e.event_version === 1).length, 0);
  } finally { gate.resolve(ack()); p.close(); }
});

test("an unaccepted attributed click restores CONTROL without resending the same action as v1", async () => {
  const p = page({ enabled: true, respond: call => call.body?.name === "app_store_cta.clicked" && call.body.event_version === 2 ? ack(false) : undefined });
  try {
    await p.ready(); p.intersect(1); await p.advance(1000); p.header.dispatch("click"); await tickPromises();
    const clicks = p.events("app_store_cta.clicked");
    assert.equal(clicks.length, 1);
    assert.equal(clicks[0].event_version, 2);
    assert.equal(p.header.textContent, "Download");
    assert.equal(p.api.getAttribution("header", "anon-golden-00", "local-session"), null);
  } finally { p.close(); }
});

test("the isolated HTTP fixture emits valid inline JavaScript and keeps OFF and ON source copies separate", async () => {
  const child = spawn(process.execPath, [path.resolve(__dirname, "../../scripts/ops/serve_growth_measurement_fixture.cjs")], { env: {}, stdio: ["ignore", "pipe", "pipe"] });
  const closed = once(child, "close");
  try {
    const info = await new Promise((resolve, reject) => {
      let output = "";
      const timer = setTimeout(() => reject(Error("fixture listener not ready")), 3000);
      child.once("error", error => { clearTimeout(timer); reject(error); });
      child.once("close", () => { clearTimeout(timer); reject(Error("fixture exited before listening")); });
      child.stdout.on("data", chunk => {
        output += chunk;
        if (output.includes("\n")) {
          clearTimeout(timer);
          try { resolve(JSON.parse(output.slice(0, output.indexOf("\n")))); } catch (error) { reject(error); }
        }
      });
    });
    assert.match(info.origin, /^http:\/\/127\.0\.0\.1:\d+$/);
    assert.notEqual(new URL(info.origin).port, "3001");
    assert.equal(info.productionWrites, 0);
    for (const address of info.urls) {
      const response = await fetch(address);
      assert.equal(response.status, 200);
      assert.match(response.headers.get("content-security-policy"), /connect-src 'self'/);
      const body = await response.text();
      const scripts = [...body.matchAll(/<script>([\s\S]*?)<\/script>/g)];
      assert.equal(scripts.length, 2);
      for (const source of scripts) assert.doesNotThrow(() => new vm.Script(source[1]), address);
      assert.match(body, /window.GROWTH_OS_EVENTS_URL = location.origin \+ '\/api\/v1\/events'/);
    }
    const off = await fetch(info.origin + "/js/main.js?fixture=off").then(r => r.text());
    const on = await fetch(info.origin + "/js/main.js?fixture=on").then(r => r.text());
    const actual = fs.readFileSync(path.join(__dirname, "main.js"), "utf8");
    assert.equal(off, actual);
    assert.equal(on, actual.replace("var HIAIR_EXPERIMENTS_ENABLED = false;", "var HIAIR_EXPERIMENTS_ENABLED = true;"));
    const invalidOrigin = await fetch(info.origin + "/api/v1/events", { method: "POST", headers: { origin: "https://hiair.io", "content-type": "application/json" }, body: "{}" });
    assert.equal(invalidOrigin.status, 403);
    assert.equal((await fetch(info.origin + "/__qa/state").then(r => r.json())).records.length, 0);
  } finally { child.kill("SIGTERM"); await closed; }
});
