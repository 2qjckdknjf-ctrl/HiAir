const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const WEB = path.join(__dirname, "..");
const store = require("./store-links.js");
const manifest = JSON.parse(fs.readFileSync(path.join(WEB, "config/store-links.json"), "utf8"));

function htmlFiles() {
  const found = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name === ".wrangler") {
        continue;
      }
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith(".html")) {
        found.push(full);
      }
    }
  }
  walk(WEB);
  return found;
}

function hrefs(html) {
  return [...html.matchAll(/\bhref=(["'])(.*?)\1/gi)].map((match) => match[2]);
}

test("store-links.js matches the JSON source of truth", () => {
  assert.equal(store.ios.status, manifest.ios.status);
  assert.equal(store.ios.url, manifest.ios.url);
  assert.equal(store.android.status, manifest.android.status);
  assert.equal(store.android.url, manifest.android.url);
});

test("iOS is PUBLIC_CONFIRMED with a canonical HTTPS App Store URL", () => {
  assert.equal(store.ios.status, "PUBLIC_CONFIRMED");
  assert.equal(store.ios.appId, "6773610034");
  assert.equal(store.ios.bundleId, "com.hiair.app");
  assert.equal(store.ios.url, "https://apps.apple.com/us/app/hiair/id6773610034");
  assert.equal(store.isPublic("ios"), true);
  assert.match(store.appStoreCampaignUrl("hero"), /^https:\/\/apps\.apple\.com\/us\/app\/hiair\/id6773610034\?/);
});

test("Android is not advertised as a public Play listing", () => {
  assert.equal(store.android.status, "NOT_PUBLIC");
  assert.equal(store.android.packageId, "com.hiair");
  assert.equal(store.android.url, null);
  assert.equal(store.isPublic("android"), false);
  assert.equal(store.playStoreCampaignUrl("hero"), "");
});

test("public HTML App Store CTAs use the verified HiAir listing", () => {
  const files = htmlFiles();
  assert.ok(files.length >= 10);
  let appStoreLinks = 0;
  for (const file of files) {
    const html = fs.readFileSync(file, "utf8");
    const rel = path.relative(WEB, file);
    for (const href of hrefs(html)) {
      assert.notEqual(href, "#", `${rel} has href="#"`);
      assert.notEqual(href, "javascript:void(0)", `${rel} has a javascript: CTA`);
      if (href.startsWith("https://play.google.com/")) {
        assert.fail(`${rel} advertises an unverified Play URL: ${href}`);
      }
      if (href.startsWith("https://apps.apple.com/")) {
        appStoreLinks += 1;
        assert.ok(href.startsWith(store.ios.url), `${rel} unexpected App Store href ${href}`);
        assert.ok(href.includes("id6773610034"), `${rel} App Store href missing HiAir id`);
      }
    }
    if (store.isPublic("ios") && rel === "index.html") {
      assert.match(html, /store-badge js-app-store-cta/);
      assert.match(html, /download-on-the-app-store\.svg/);
      assert.match(html, /app-store-qr\.svg/);
      assert.doesNotMatch(html, /play-badge|google-play-badge/i);
    }
  }
  assert.ok(appStoreLinks > 0, "expected at least one App Store CTA");
});

test("App Store badge assets exist only because iOS is public", () => {
  const badge = path.join(WEB, "assets/badges/download-on-the-app-store.svg");
  const qr = path.join(WEB, "assets/badges/app-store-qr.svg");
  assert.equal(fs.existsSync(badge), store.isPublic("ios"));
  assert.equal(fs.existsSync(qr), store.isPublic("ios"));
  const qrText = fs.readFileSync(qr, "utf8");
  assert.ok(qrText.includes(`payload: ${store.ios.url}`));
});

test("live product copy no longer claims the whole product is still in development", () => {
  const banned = [
    /coming soon/i,
    /launching soon/i,
    /in development/i,
    /under development/i,
    /join early access for ios and android/i,
    /ios &amp; android coming soon/i,
    /website under development/i,
    /play store coming soon/i,
    /app store coming soon/i,
  ];
  for (const file of htmlFiles()) {
    const html = fs.readFileSync(file, "utf8");
    const rel = path.relative(WEB, file);
    for (const pattern of banned) {
      assert.doesNotMatch(html, pattern, `${rel} still contains ${pattern}`);
    }
  }
});
