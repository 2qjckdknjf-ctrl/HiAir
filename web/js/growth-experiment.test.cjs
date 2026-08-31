const { test } = require("node:test");
const assert = require("node:assert/strict");
const assignment = require("./growth-experiment-assignment.js");
const exposure = require("./growth-experiment-exposure.js");
const config = require("./growth-experiment-config.js");
const telemetry = require("./growth-experiment-telemetry.js");
const runtime = require("./growth-experiment-runtime.js");

const EXPERIMENT_ID = "11111111-1111-4111-8111-111111111111";
const CONTROL = "22222222-2222-4222-8222-222222222222";
const TREATMENT = "33333333-3333-4333-8333-333333333333";
const allocation = [
  { variant_id: CONTROL, role: "CONTROL", weight: 0.5, public_config: {} },
  { variant_id: TREATMENT, role: "TREATMENT", weight: 0.5, public_config: { cta_copy: "Get HiAir on the App Store" } },
];

function memoryStorage() {
  const mem = new Map();
  return {
    getItem: (key) => mem.get(key) ?? null,
    setItem: (key, value) => mem.set(key, String(value)),
  };
}

test("flag off and missing config stay CONTROL", async () => {
  const result = await runtime.start({ enabled: false });
  assert.equal(result.variant, "CONTROL");
  const empty = await config.failClosedFetch({ enabled: true, url: "", fetch: null });
  assert.deepEqual(empty, { experiments: [] });
});

test("sticky assignment does not change across sessions", () => {
  const storage = memoryStorage();
  const first = assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-sticky",
    allocation,
    storage,
  });
  const second = assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-sticky",
    allocation,
    storage,
  });
  assert.equal(first.variant_id, second.variant_id);
  assert.equal(second.source, "sticky");
});

test("exposure requires 50% for 1000ms and retries after transport failure", async () => {
  assert.equal(exposure.conditionMet(0.49, 5000), false);
  assert.equal(exposure.conditionMet(0.5, 999), false);
  assert.equal(exposure.conditionMet(0.5, 1000), true);
  let now = 0;
  let attempts = 0;
  const watcher = exposure.watchExposure({
    experimentId: EXPERIMENT_ID,
    variantId: CONTROL,
    anonymousId: "anon",
    placement: "header",
    now: () => now,
    send: () => {
      attempts += 1;
      if (attempts === 1) {
        return Promise.reject(new Error("network"));
      }
      return Promise.resolve();
    },
  });
  watcher.onRatio(0.5);
  now = 1000;
  watcher.onRatio(0.5);
  await Promise.resolve();
  await Promise.resolve();
  watcher.onRatio(0.5);
  now = 2000;
  watcher.onRatio(0.5);
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(attempts, 2);
});

test("public config rejects script payloads and applies textContent only", () => {
  assert.deepEqual(config.publicConfig({ cta_copy: "<script>x</script>" }), {});
  const el = { textContent: "Download on the App Store" };
  config.applyCtaCopy(el, "Get HiAir on the App Store");
  assert.equal(el.textContent, "Get HiAir on the App Store");
});

test("runtime fail-closed when fetch throws", async () => {
  const result = await runtime.start({
    enabled: true,
    configUrl: "https://growth.example/api/v1/experiments/active",
    fetch: () => Promise.reject(new Error("down")),
    configApi: config,
    assignmentApi: assignment,
    telemetryApi: telemetry,
    exposureApi: exposure,
    anonymousId: "anon",
    sessionId: "s1",
    storage: memoryStorage(),
  });
  assert.equal(result.variant, "CONTROL");
});

test("10k hash assignments stay near 50/50 and do not switch", () => {
  let control = 0;
  let switches = 0;
  for (let i = 0; i < 10000; i += 1) {
    const assigned = assignment.assignFromHash({
      experimentId: EXPERIMENT_ID,
      assignmentVersion: "v1",
      anonymousId: "pop-" + i,
      allocation,
    });
    if (assigned.role === "CONTROL") {
      control += 1;
    }
  }
  assert.ok(control >= 4700 && control <= 5300, "control=" + control);
  for (let i = 0; i < 1000; i += 1) {
    const first = assignment.assignFromHash({
      experimentId: EXPERIMENT_ID,
      assignmentVersion: "v1",
      anonymousId: "sticky-" + i,
      allocation,
    });
    for (let round = 0; round < 5; round += 1) {
      const again = assignment.assignFromHash({
        experimentId: EXPERIMENT_ID,
        assignmentVersion: "v1",
        anonymousId: "sticky-" + i,
        allocation,
      });
      if (again.variant_id !== first.variant_id) {
        switches += 1;
      }
    }
  }
  assert.equal(switches, 0);
});
