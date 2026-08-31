(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_EXPERIMENT_TELEMETRY = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function assignmentEventId(experimentId, anonymousId, assignmentVersion) {
    return ["experiment.assigned", experimentId, anonymousId, assignmentVersion].join(":");
  }

  function send(input) {
    if (!input.url || !input.fetch) {
      return Promise.resolve({ ok: false });
    }
    var body = {
      productSlug: "hiair",
      surface: "website",
      environment: "production",
      event_version: 2,
      anonymousId: input.anonymousId,
      session_id: input.sessionId,
      event_id: input.eventId,
      name: input.name,
      occurredAt: new Date().toISOString(),
      properties: {
        placement: input.placement,
        experiment_id: input.experimentId,
        variant_id: input.variantId,
        assignment_version: input.assignmentVersion,
      },
    };
    return input
      .fetch(input.url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
        keepalive: true,
      })
      .then(function (response) {
        if (!response || !response.ok) {
          throw new Error("transport");
        }
        return { ok: true };
      });
  }

  return {
    assignmentEventId: assignmentEventId,
    send: send,
  };
});
