(function (root, factory) {
  var api = factory(root);
  if (typeof module === "object" && module.exports) module.exports = api;
  root.HIAIR_GROWTH_EXPERIMENT_TELEMETRY = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function (root) {
  function assignmentEventId(experimentId, anonymousId, assignmentVersion) {
    return ["experiment.assigned", experimentId, anonymousId, assignmentVersion].join(":");
  }
  function accepted(result) {
    var b = result && result.body;
    return !!b && b.ok === true && ((result.status === 202 && b.stored === true && b.duplicate === false) ||
      (result.status === 200 && b.stored === false && b.duplicate === true));
  }
  function send(input) {
    var transport = input.configApi || root.HIAIR_GROWTH_EXPERIMENT_CONFIG;
    if (!transport || typeof transport.requestJson !== "function" || typeof input.eventId !== "string" || input.eventId.length > 200 ||
      typeof input.anonymousId !== "string" || !input.anonymousId || input.anonymousId.length > 128 ||
      typeof input.occurredAt !== "string" || !Number.isFinite(Date.parse(input.occurredAt))) return Promise.reject(new Error("telemetry_invalid"));
    var body = { productSlug: "hiair", surface: "website", environment: "production", event_version: 2,
      anonymousId: input.anonymousId, session_id: input.sessionId, event_id: input.eventId, name: input.name, occurredAt: input.occurredAt,
      properties: { placement: input.placement, experiment_id: input.experimentId, variant_id: input.variantId, assignment_version: input.assignmentVersion } };
    return transport.requestJson({ url: input.url, fetch: input.fetch, method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify(body), timeoutMs: input.timeoutMs, signal: input.signal }).then(function (response) {
      if (!accepted(response)) throw new Error("receipt_unverified");
      return { ok: true, stored: response.body.stored, duplicate: response.body.duplicate };
    });
  }
  return { assignmentEventId: assignmentEventId, accepted: accepted, send: send };
});
