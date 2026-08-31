const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");

const golden = JSON.parse(fs.readFileSync(path.join(__dirname, "assignment-golden-vectors.json"), "utf8"));
const EXPERIMENT_ID = "11111111-1111-4111-8111-111111111111";
const CONTROL = "22222222-2222-4222-8222-222222222222";
const TREATMENT = "33333333-3333-4333-8333-333333333333";
const allocation = golden.allocation;

function memoryStorage() {
  const mem = new Map();
  return {
    getItem: (key) => mem.get(key) ?? null,
    setItem: (key, value) => mem.set(key, String(value)),
  };
}

function loadAssignment(options) {
  const source = fs.readFileSync(path.join(__dirname, "growth-experiment-assignment.js"), "utf8");
  const sandbox = {
    crypto: options && Object.prototype.hasOwnProperty.call(options, "crypto") ? options.crypto : webcrypto,
    TextEncoder,
    Uint8Array,
    Promise,
    Date,
    JSON,
    Array,
    Object,
    Math,
    Number,
    String,
    Boolean,
    parseInt,
    isFinite,
    console,
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  assert.equal(typeof sandbox.require, "undefined");
  assert.equal(typeof sandbox.module, "undefined");
  vm.runInContext(source, sandbox);
  assert.ok(sandbox.HIAIR_GROWTH_ASSIGNMENT);
  return sandbox.HIAIR_GROWTH_ASSIGNMENT;
}

test("browser runtime has no require and uses Web Crypto", async () => {
  const api = loadAssignment();
  const buckets = new Set();
  for (const vector of golden.vectors) {
    const assigned = await api.assignFromHash({
      experimentId: vector.experiment_id,
      assignmentVersion: vector.assignment_version,
      anonymousId: vector.anonymous_id,
      allocation,
    });
    assert.equal(assigned.source, "hash", vector.anonymous_id);
    assert.equal(assigned.sha256_prefix, vector.sha256_prefix, vector.anonymous_id);
    assert.equal(assigned.role, vector.expected_role, vector.anonymous_id);
    buckets.add(assigned.bucket);
  }
  assert.equal(golden.vectors.length, 20);
  assert.ok(buckets.size > 1);
  assert.ok(![...buckets].every((value) => value === 0));
});

test("browser assignment is not always bucket 0", async () => {
  const api = loadAssignment();
  const first = await api.assignFromHash({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-00",
    allocation,
  });
  const second = await api.assignFromHash({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-01",
    allocation,
  });
  assert.notEqual(first.bucket, 0);
  assert.notEqual(first.bucket, second.bucket);
  assert.equal(first.role, "TREATMENT");
  assert.equal(second.role, "CONTROL");
});

test("browser crypto unavailable fails closed to CONTROL", async () => {
  const api = loadAssignment({ crypto: undefined });
  const assigned = await api.assignFromHash({
    experimentId: EXPERIMENT_ID,
    assignmentVersion: "v1",
    anonymousId: "anon-golden-00",
    allocation,
  });
  assert.equal(assigned.role, "CONTROL");
  assert.equal(assigned.source, "control_fallback");
  assert.equal(assigned.reason, "crypto_unavailable");
});

test("10k browser Web Crypto assignments stay near 50/50", async () => {
  const api = loadAssignment();
  const pending = [];
  for (let i = 0; i < 10000; i += 1) {
    pending.push(
      api.assignFromHash({
        experimentId: EXPERIMENT_ID,
        assignmentVersion: "v1",
        anonymousId: "pop-" + i,
        allocation,
      }),
    );
  }
  const assigned = await Promise.all(pending);
  let control = 0;
  let treatment = 0;
  let hashSource = 0;
  for (const row of assigned) {
    assert.notEqual(row.source, "control_fallback");
    if (row.role === "CONTROL") {
      control += 1;
    } else if (row.role === "TREATMENT") {
      treatment += 1;
    }
    if (row.source === "hash") {
      hashSource += 1;
    }
  }
  assert.equal(hashSource, 10000);
  assert.notEqual(control, 10000);
  assert.ok(control >= 4700 && control <= 5300, "CONTROL=" + control);
  assert.ok(treatment >= 4700 && treatment <= 5300, "TREATMENT=" + treatment);
  globalThis.__HIAIR_BROWSER_10K__ = { control, treatment };
});

test("1000 browser sticky visitors stay put across reload and new session", async () => {
  const storage = memoryStorage();
  const firstApi = loadAssignment();
  let switches = 0;
  const firstIds = [];
  for (let i = 0; i < 1000; i += 1) {
    const assigned = await firstApi.assignVisitor({
      experimentId: EXPERIMENT_ID,
      assignmentVersion: "v1",
      anonymousId: "sticky-pop-" + i,
      allocation,
      storage,
      sessionId: "session-a-" + i,
    });
    firstIds.push(assigned.variant_id);
  }
  const reloaded = loadAssignment();
  for (let i = 0; i < 1000; i += 1) {
    const again = await reloaded.assignVisitor({
      experimentId: EXPERIMENT_ID,
      assignmentVersion: "v1",
      anonymousId: "sticky-pop-" + i,
      allocation,
      storage,
      sessionId: "session-b-" + i,
    });
    assert.equal(again.source, "sticky");
    if (again.variant_id !== firstIds[i]) {
      switches += 1;
    }
  }
  assert.equal(switches, 0);
});
