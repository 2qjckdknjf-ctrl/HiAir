const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const assignment = require("./growth-experiment-assignment.js");
const exposure = require("./growth-experiment-exposure.js");
const config = require("./growth-experiment-config.js");
const telemetry = require("./growth-experiment-telemetry.js");
const runtime = require("./growth-experiment-runtime.js");

const golden = JSON.parse(fs.readFileSync(path.join(__dirname, "assignment-golden-vectors.json"), "utf8"));
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

function experimentPayload(overrides) {
  return {
    id: EXPERIMENT_ID,
    assignment_version: "v1",
    surface: "website",
    placement: "header",
    allocation,
    ...overrides,
  };
}

test("flag off does not fetch config or apply treatment", async () => {
  let fetches = 0;
  const cta = { textContent: "Download on the App Store" };
  const result = await runtime.start({
    enabled: false,
    configUrl: "https://growth.example/api/v1/experiments/active",
    fetch: () => {
      fetches += 1;
      return Promise.resolve({ ok: true, json: async () => ({ experiments: [experimentPayload()] }) });
    },
    configApi: config,
    assignmentApi: assignment,
    telemetryApi: telemetry,
    ctaEl: cta,
  });
  assert.equal(result.variant, "CONTROL");
  assert.equal(result.reason, "flag_off");
  assert.equal(fetches, 0);
  assert.equal(cta.textContent, "Download on the App Store");
});

test("golden vectors match Web Crypto SHA-256 prefixes and variants", async () => {
  assert.equal(golden.vectors.length, 20);
  for (const vector of golden.vectors) {
    const hex = await assignment.sha256Hex(
      `${vector.experiment_id}:${vector.assignment_version}:${vector.anonymous_id}`,
    );
    assert.ok(hex, "sha256 missing for " + vector.anonymous_id);
    assert.equal(hex.slice(0, 12), vector.sha256_prefix, vector.anonymous_id);
    const assigned = await assignment.assignFromHash({
      experimentId: vector.experiment_id,
      assignmentVersion: vector.assignment_version,
      anonymousId: vector.anonymous_id,
      allocation: golden.allocation,
    });
    assert.equal(assigned.source, "hash");
    assert.equal(assigned.sha256_prefix, vector.sha256_prefix);
    assert.equal(assigned.role, vector.expected_role);
    assert.equal(assigned.variant_id, vector.expected_variant_id);
    assert.ok(Math.abs(assigned.bucket - vector.expected_bucket) < 1e-12);
  }
});

test("sticky assignment does not change across sessions", async () => {
  const storage = memoryStorage();
  const first = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-sticky",
    allocation,
    storage,
  });
  const second = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-sticky",
    allocation,
    storage,
  });
  assert.equal(first.variant_id, second.variant_id);
  assert.equal(second.source, "sticky");
});

test("assignment_version v2 does not leak v1 sticky assignment", async () => {
  const storage = memoryStorage();
  const v1 = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-versioned",
    allocation,
    storage,
  });
  const v2 = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v2",
    anonymousId: "anon-versioned",
    allocation,
    storage,
  });
  assert.equal(v1.source, "hash");
  assert.equal(v2.source, "hash");
  assert.notEqual(assignment.storageKey(EXPERIMENT_ID, "v1"), assignment.storageKey(EXPERIMENT_ID, "v2"));
  assert.ok(storage.getItem(assignment.storageKey(EXPERIMENT_ID, "v1")));
  assert.ok(storage.getItem(assignment.storageKey(EXPERIMENT_ID, "v2")));
});

test("sticky visitor stays put when allocation weights change for the same version", async () => {
  const storage = memoryStorage();
  const first = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-weight",
    allocation,
    storage,
  });
  const skewed = [
    { variant_id: CONTROL, role: "CONTROL", weight: 0.01, public_config: {} },
    { variant_id: TREATMENT, role: "TREATMENT", weight: 0.99, public_config: { cta_copy: "Get HiAir on the App Store" } },
  ];
  const second = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-weight",
    allocation: skewed,
    storage,
  });
  assert.equal(second.source, "sticky");
  assert.equal(second.variant_id, first.variant_id);
});

test("unknown stored variant is not executed", async () => {
  const storage = memoryStorage();
  storage.setItem(
    assignment.storageKey(EXPERIMENT_ID, "v1"),
    JSON.stringify({
      variant_id: "99999999-9999-4999-8999-999999999999",
      experiment_id: EXPERIMENT_ID,
      assignment_version: "v1",
    }),
  );
  const assigned = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-stale",
    allocation,
    storage,
  });
  assert.notEqual(assigned.variant_id, "99999999-9999-4999-8999-999999999999");
  assert.ok(assigned.source === "hash" || assigned.source === "control_fallback");
});

test("storage unavailable and write failure return CONTROL not treatment", async () => {
  const hashed = await assignment.assignFromHash({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-00",
    allocation,
  });
  assert.equal(hashed.role, "TREATMENT");
  const noStorage = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-00",
    allocation,
  });
  assert.equal(noStorage.role, "CONTROL");
  assert.equal(noStorage.source, "control_fallback");
  const failing = {
    getItem: () => null,
    setItem: () => {
      throw new Error("quota");
    },
  };
  const writeFail = await assignment.assignVisitor({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-00",
    allocation,
    storage: failing,
  });
  assert.equal(writeFail.role, "CONTROL");
  assert.equal(writeFail.reason, "storage_write_failure");
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
  assert.equal(Object.prototype.hasOwnProperty.call(el, "innerHTML"), false);
});

test("control fallback matrix never applies treatment", async () => {
  const cta = { textContent: "Download on the App Store" };
  const cases = [
    {
      name: "config unavailable",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () => Promise.reject(new Error("down")),
      },
    },
    {
      name: "empty config",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () => Promise.resolve({ ok: true, json: async () => ({ experiments: [] }) }),
      },
    },
    {
      name: "malformed experiment",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () => Promise.resolve({ ok: true, json: async () => ({ experiments: [{ id: "x" }] }) }),
      },
    },
    {
      name: "missing CONTROL",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () =>
          Promise.resolve({
            ok: true,
            json: async () => ({
              experiments: [
                experimentPayload({
                  allocation: [{ variant_id: TREATMENT, role: "TREATMENT", weight: 1, public_config: { cta_copy: "Treat" } }],
                }),
              ],
            }),
          }),
      },
    },
    {
      name: "invalid treatment config",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () =>
          Promise.resolve({
            ok: true,
            json: async () => ({
              experiments: [
                experimentPayload({
                  allocation: [
                    { variant_id: CONTROL, role: "CONTROL", weight: 0, public_config: {} },
                    { variant_id: TREATMENT, role: "TREATMENT", weight: 1, public_config: { cta_copy: "<script>x</script>" } },
                  ],
                }),
              ],
            }),
          }),
        storage: memoryStorage(),
        anonymousId: "anon-golden-00",
      },
    },
  ];
  for (const row of cases) {
    cta.textContent = "Download on the App Store";
    const result = await runtime.start({
      configApi: config,
      assignmentApi: assignment,
      telemetryApi: telemetry,
      exposureApi: exposure,
      ctaEl: cta,
      anonymousId: "anon",
      sessionId: "s1",
      eventsUrl: "",
      ...row.input,
    });
    assert.equal(result.variant, "CONTROL", row.name);
    assert.equal(cta.textContent, "Download on the App Store", row.name);
  }
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
