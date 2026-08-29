const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const WEB = path.join(__dirname, "..");
const CONFIG = JSON.parse(fs.readFileSync(path.join(WEB, "config", "store-links.json"), "utf8"));

function loadStoreLinks() {
  const source = fs.readFileSync(path.join(__dirname, "store-links.js"), "utf8");
  const root = {};
  vm.runInNewContext(source, {
    module: { exports: {} },
    exports: {},
    URLSearchParams,
    globalThis: root,
  });
  return root.HIAIR_STORE_LINKS;
}

function htmlFiles() {
  const files = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === ".wrangler") {
          continue;
        }
        walk(full);
      } else if (entry.name.endsWith(".html")) {
        files.push(full);
      }
    }
  }
  walk(WEB);
  return files;
}

function hrefs(html) {
  return [...html.matchAll(/href="([^"]*)"/g)].map((match) => match[1]);
}

test("store-links.js matches config/store-links.json", () => {
  const links = loadStoreLinks();
  assert.equal(links.ios.status, CONFIG.ios.status);
  assert.equal(links.ios.appId, CONFIG.ios.appId);
  assert.equal(links.ios.url, CONFIG.ios.url);
  assert.equal(links.android.status, CONFIG.android.status);
  assert.equal(links.android.packageId, CONFIG.android.packageId);
  assert.equal(links.android.url, CONFIG.android.url);
});

test("public store URLs are HTTPS and campaign helpers respect status", () => {
  const links = loadStoreLinks();
  assert.equal(links.ios.status, "PUBLIC_CONFIRMED");
  assert.match(links.ios.url, /^https:\/\/apps\.apple\.com\/us\/app\/hiair\/id6773610034$/);
  const campaign = links.appStoreCampaignUrl("hero");
  assert.equal(campaign.startsWith(links.ios.url + "?"), true);
  assert.match(campaign, /utm_content=hero/);
  assert.equal(links.android.status, "NOT_PUBLIC");
  assert.equal(links.android.url, null);
  assert.equal(links.playStoreCampaignUrl("hero"), "");
  assert.equal(links.isPublic("ios"), true);
  assert.equal(links.isPublic("android"), false);
});

test("App Store badge markup is present iff iOS is PUBLIC_CONFIRMED", () => {
  const homepage = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
  const hasBadge = homepage.includes('src="/assets/badges/download-on-the-app-store.svg"');
  assert.equal(hasBadge, CONFIG.ios.status === "PUBLIC_CONFIRMED");
  assert.equal(homepage.includes("js-play-store-cta"), false);
  assert.equal(homepage.includes("play.google.com/store/apps/details"), false);
});

test("public HTML download CTAs use verified HTTPS store URLs and never href=#", () => {
  const iosPublic = CONFIG.ios.status === "PUBLIC_CONFIRMED";
  const androidPublic = CONFIG.android.status === "PUBLIC_CONFIRMED";
  for (const file of htmlFiles()) {
    const html = fs.readFileSync(file, "utf8");
    const rel = path.relative(WEB, file);
    for (const href of hrefs(html)) {
      assert.notEqual(href, "#", `${rel} has placeholder href="#"`);
      assert.notEqual(href, "javascript:void(0)", `${rel} has a dead javascript CTA`);
      if (href.startsWith("https://apps.apple.com/")) {
        assert.equal(iosPublic, true, `${rel} has an App Store URL while iOS is not public`);
        assert.equal(href.startsWith(CONFIG.ios.url), true, `${rel} App Store href is not canonical: ${href}`);
      }
      if (href.startsWith("https://play.google.com/")) {
        assert.equal(androidPublic, true, `${rel} has a Play URL while Android is not public`);
      }
    }
    const ctaBlocks = [...html.matchAll(/class="[^"]*js-app-store-cta[^"]*"/g)];
    if (iosPublic) {
      if (rel === "index.html" || rel.endsWith("/index.html")) {
        assert.ok(ctaBlocks.length > 0 || rel.includes("privacy") || rel.includes("terms") || rel === "404.html", `${rel} is missing App Store CTA`);
      }
    } else {
      assert.equal(ctaBlocks.length, 0, `${rel} still renders App Store CTA`);
    }
  }
});

test("public HTML does not claim a pre-launch product state", () => {
  const banned = [
    "coming soon",
    "launching soon",
    "in development",
    "under development",
    "join early access for ios and android",
  ];
  for (const file of htmlFiles()) {
    const html = fs.readFileSync(file, "utf8").toLowerCase();
    for (const phrase of banned) {
      assert.equal(html.includes(phrase), false, `${path.relative(WEB, file)} still contains ${phrase}`);
    }
  }
});
