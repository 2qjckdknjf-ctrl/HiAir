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
    getAttribute: (name) => (name === "data-placement" ? "hero" : null),
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
  assert.equal(clicks.length, 2);
  assert.doesNotThrow(() => win.listeners[0].fn());
});
