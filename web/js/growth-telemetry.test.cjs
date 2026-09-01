const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function loadMain(windowLike) {
  const source = fs.readFileSync(path.join(__dirname, "main.js"), "utf8");
  const context = vm.createContext({
    window: windowLike,
    document: windowLike.document,
    URLSearchParams,
    Date,
    fetch: windowLike.fetch,
    console,
  });
  vm.runInContext(source, context);
  return windowLike;
}

function fakeWindow(overrides) {
  const mem = new Map();
  const storage = {
    getItem: (key) => mem.get(key) ?? null,
    setItem: (key, value) => mem.set(key, String(value)),
  };
  const listeners = [];
  const cta = {
    getAttribute: (name) => {
      if (name === "data-placement") return "hero";
      if (name === "data-event") return "hero_app_store_click";
      return null;
    },
    addEventListener: (type, fn) => listeners.push({ type, fn }),
  };
  const windowLike = {
    GROWTH_OS_EVENTS_URL: overrides.eventsUrl,
    location: { hostname: overrides.hostname ?? "hiair.io", pathname: "/", search: overrides.search ?? "" },
    localStorage: storage,
    sessionStorage: storage,
    crypto: { randomUUID: () => "id-1" },
    fetch: overrides.fetch,
    matchMedia: () => ({ matches: true }),
    document: {
      documentElement: { lang: "en" },
      querySelector: () => null,
      querySelectorAll: (selector) => {
        if (selector === ".js-app-store-cta") {
          return [cta];
        }
        if (selector === ".lg--glow") {
          return [];
        }
        return [];
      },
      getElementById: () => null,
    },
    listeners,
    cta,
  };
  return windowLike;
}

test("CTA still binds when the Growth OS endpoint is missing", () => {
  const calls = [];
  const win = fakeWindow({
    eventsUrl: "",
    hostname: "hiair.io",
    fetch: (...args) => {
      calls.push(args);
      return Promise.resolve();
    },
  });
  loadMain(win);
  assert.equal(win.listeners.length, 1);
  win.listeners[0].fn();
  assert.equal(calls.length, 0);
});

test("view event is not duplicated for the same placement", () => {
  const calls = [];
  const win = fakeWindow({
    eventsUrl: "https://growth.example/api/v1/events",
    fetch: (...args) => {
      calls.push(args);
      return Promise.resolve();
    },
  });
  loadMain(win);
  assert.equal(calls.length, 1);
  const body = JSON.parse(calls[0][1].body);
  assert.equal(body.name, "app_store_cta.viewed");
  assert.equal(body.event_id, "id-1");
});

test("flag off does not start experiment runtime or emit experiment telemetry", () => {
  let starts = 0;
  const calls = [];
  const win = fakeWindow({
    eventsUrl: "https://growth.example/api/v1/events",
    fetch: (...args) => {
      calls.push(args);
      return Promise.resolve();
    },
  });
  win.HIAIR_GROWTH_EXPERIMENT = {
    start: () => {
      starts += 1;
      return Promise.resolve({ variant: "TREATMENT" });
    },
  };
  loadMain(win);
  assert.equal(starts, 0);
  const names = calls.map((call) => JSON.parse(call[1].body).name);
  assert.ok(names.every((name) => name === "app_store_cta.viewed" || name === "app_store_cta.clicked"));
  assert.equal(
    names.includes("experiment.assigned") || names.includes("experiment.exposed"),
    false,
  );
});

test("production HTML does not load experiment scripts", () => {
  const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");
  assert.equal(html.includes("growth-experiment"), false);
  const main = fs.readFileSync(path.join(__dirname, "main.js"), "utf8");
  assert.match(main, /var HIAIR_EXPERIMENTS_ENABLED = false;/);
});

test("click emits once and CTA still works if telemetry rejects", () => {
  const calls = [];
  const win = fakeWindow({
    eventsUrl: "https://growth.example/api/v1/events",
    fetch: (...args) => {
      calls.push(args);
      return Promise.reject(new Error("down"));
    },
  });
  loadMain(win);
  win.listeners[0].fn();
  win.listeners[0].fn();
  const clicks = calls.filter((call) => JSON.parse(call[1].body).name === "app_store_cta.clicked");
  const iosDownloads = calls.filter((call) => JSON.parse(call[1].body).name === "ios_download_click");
  const heroClicks = calls.filter((call) => JSON.parse(call[1].body).name === "hero_app_store_click");
  assert.equal(clicks.length, 2);
  assert.equal(iosDownloads.length, 2);
  assert.equal(heroClicks.length, 2);
  assert.doesNotThrow(() => win.listeners[0].fn());
});

test("premium homepage declares the required non-sensitive conversion events", () => {
  const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");
  const main = fs.readFileSync(path.join(__dirname, "main.js"), "utf8");
  [
    "hero_app_store_click",
    "header_download_click",
    "demo_started",
    "demo_completed",
    "premium_viewed",
    "faq_opened",
    "final_cta_click",
    "ios_download_click",
    "android_download_click",
  ].forEach((eventName) => {
    assert.ok(html.includes(eventName) || main.includes(eventName), `missing ${eventName}`);
  });
  assert.doesNotMatch(main, /trackGrowth\([^\n]+(?:latitude|longitude|health|email)/i);
});
