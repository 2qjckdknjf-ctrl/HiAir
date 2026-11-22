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

function runtimeInput(overrides = {}) {
  const doc = { visibilityState:"visible", hidden:false, documentElement:{}, addEventListener(){}, removeEventListener(){} };
  class Observer { observe(){} unobserve(){} disconnect(){} }
  return { configApi:config, assignmentApi:assignment, telemetryApi:telemetry, exposureApi:exposure,
    enabled:true, placement:"header", document:doc, IntersectionObserver:Observer, MutationObserver:Observer,
    configUrl:"https://growth.example/api/v1/experiments/active", eventsUrl:"https://growth.example/api/v1/events",
    ctaEl:{textContent:"Download",isConnected:true,childElementCount:0}, storage:memoryStorage(),
    anonymousId:"anon-golden-00", sessionId:"fixture-session", ...overrides };
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
      return Promise.resolve({ ok: true, status: 200, json: async () => ({ experiments: [experimentPayload()] }) });
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
  assert.notEqual(assignment.storageKey(EXPERIMENT_ID, "v1", "anon-versioned"), assignment.storageKey(EXPERIMENT_ID, "v2", "anon-versioned"));
  assert.ok(storage.getItem(assignment.storageKey(EXPERIMENT_ID, "v1", "anon-versioned")));
  assert.ok(storage.getItem(assignment.storageKey(EXPERIMENT_ID, "v2", "anon-versioned")));
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
    assignment.storageKey(EXPERIMENT_ID, "v1", "anon-stale"),
    JSON.stringify({
      variant_id: "99999999-9999-4999-8999-999999999999",
      experiment_id: EXPERIMENT_ID,
      assignment_version: "v1",
      anonymous_id: "anon-stale",
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

test("exposure schedules one deadline, resets broken visibility, and requires a receipt", async () => {
  assert.equal(exposure.conditionMet(0.49, 5000), false);
  assert.equal(exposure.conditionMet(0.5, 999), false);
  assert.equal(exposure.conditionMet(0.5, 1000), true);
  let now = 0, timer, attempts = 0, acknowledged = 0;
  const watcher = exposure.watchExposure({
    experimentId: EXPERIMENT_ID, variantId: CONTROL, anonymousId: "anon", placement: "header",
    now: () => now, setTimeout: fn => { timer=fn; return 1; }, clearTimeout: () => { timer=null; },
    send: async () => { attempts++; return {ok:true}; }, onAcknowledged:()=>{acknowledged++;}
  });
  watcher.onRatio(.5); now=600; watcher.onRatio(.49);
  assert.equal(timer,null);
  now=1000;watcher.onRatio(.5); now=2000; timer();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(attempts,1); assert.equal(acknowledged,1);
  watcher.onRatio(.5);assert.equal(attempts,1);watcher.stop();
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
        fetch: () => Promise.resolve({ ok: true, status: 200, json: async () => ({ experiments: [] }) }),
      },
    },
    {
      name: "malformed experiment",
      input: {
        enabled: true,
        configUrl: "https://growth.example/api/v1/experiments/active",
        fetch: () => Promise.resolve({ ok: true, status: 200, json: async () => ({ experiments: [{ id: "x" }] }) }),
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
            status: 200,
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
            status: 200,
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
    const result = await runtime.start(runtimeInput({
      configApi: config,
      assignmentApi: assignment,
      telemetryApi: telemetry,
      exposureApi: exposure,
      ctaEl: cta,
      anonymousId: "anon",
      sessionId: "s1",
      ...row.input,
    }));
    assert.equal(result.variant, "CONTROL", row.name);
    assert.equal(cta.textContent, "Download on the App Store", row.name);
  }
});

test("runtime fail-closed when fetch throws", async () => {
  const result = await runtime.start(runtimeInput({
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
  }));
  assert.equal(result.variant, "CONTROL");
});


test("bounded transport rejects oversized UTF-8 requests before sending and oversized responses before parsing", async () => {
  let requests=0;
  await assert.rejects(config.requestJson({url:"https://fixture.invalid/events",method:"POST",body:"😀".repeat(2049),fetch:async()=>{requests++;}}),/request_too_large/);
  assert.equal(requests,0);
  await assert.rejects(config.requestJson({url:"https://fixture.invalid/config",fetch:async()=>new Response('"'+"x".repeat(16385)+'"',{status:200})}),/response_too_large/);
});

test("config request deadline aborts a never-settling response and ignores a late success", async () => {
  let resolveFetch, signal;
  const pending=config.requestJson({url:"https://fixture.invalid/config",timeoutMs:10,
    fetch:(_url,options)=>{signal=options.signal;return new Promise(resolve=>{resolveFetch=resolve;});}});
  await assert.rejects(pending,/transport_timeout/);
  assert.equal(signal.aborted,true);
  resolveFetch(new Response(JSON.stringify({experiments:[]}),{status:200}));
  await new Promise(resolve=>setImmediate(resolve));
});

test("telemetry accepts only consistent durable acknowledgement bodies and status", async () => {
  const base={configApi:config,url:"https://fixture.invalid/events",eventId:"fixture-id",anonymousId:"fixture-anon",sessionId:"fixture-session",
    occurredAt:new Date().toISOString(),name:"experiment.assigned",placement:"header",experimentId:EXPERIMENT_ID,variantId:TREATMENT,assignmentVersion:"v1"};
  for (const [status,body,valid] of [
    [202,{ok:true,stored:true,duplicate:false},true], [200,{ok:true,stored:false,duplicate:true},true],
    [200,{ok:true,stored:true,duplicate:false},false], [202,{ok:true,stored:false,duplicate:true},false],
    [202,{ok:true,stored:true,duplicate:true},false], [202,{ok:true,stored:false,duplicate:false},false],
    [202,{ok:false,stored:true,duplicate:false},false], [202,{ok:true},false], [200,{error:"wrong service"},false]
  ]) {
    const send=telemetry.send({...base,fetch:async()=>new Response(JSON.stringify(body),{status})});
    if(valid) assert.equal((await send).ok,true); else await assert.rejects(send,/receipt_unverified/);
  }
});
