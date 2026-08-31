(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_EXPERIMENT = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var CONTROL_COPY = "Download on the App Store";

  function start(input) {
    var enabled = Boolean(input && input.enabled);
    var configApi = (input && input.configApi) || {};
    var assignmentApi = (input && input.assignmentApi) || {};
    var telemetryApi = (input && input.telemetryApi) || {};
    var exposureApi = (input && input.exposureApi) || {};
    if (!enabled) {
      return Promise.resolve({ variant: "CONTROL", reason: "flag_off" });
    }
    return (configApi.failClosedFetch
      ? configApi.failClosedFetch({
          enabled: true,
          url: input.configUrl,
          fetch: input.fetch,
        })
      : Promise.resolve({ experiments: [] })
    )
      .then(function (payload) {
        var experiment = payload && payload.experiments && payload.experiments[0];
        if (!experiment) {
          return { variant: "CONTROL", reason: "no_active_experiment" };
        }
        var assigned = assignmentApi.assignVisitor({
          experimentId: experiment.id,
          assignmentVersion: experiment.assignment_version,
          anonymousId: input.anonymousId,
          allocation: experiment.allocation,
          storage: input.storage,
        });
        if (!assigned || !assigned.variant_id) {
          return { variant: "CONTROL", reason: "assignment_failure" };
        }
        var chosen = (experiment.allocation || []).find(function (row) {
          return row.variant_id === assigned.variant_id;
        });
        if (!chosen) {
          return { variant: "CONTROL", reason: "bad_variant" };
        }
        if (chosen.role === "TREATMENT" && chosen.public_config && chosen.public_config.cta_copy && input.ctaEl) {
          configApi.applyCtaCopy(input.ctaEl, chosen.public_config.cta_copy);
        } else if (input.ctaEl && !input.ctaEl.textContent) {
          input.ctaEl.textContent = CONTROL_COPY;
        }
        var assignmentId = telemetryApi.assignmentEventId(
          experiment.id,
          input.anonymousId,
          experiment.assignment_version,
        );
        return telemetryApi
          .send({
            url: input.eventsUrl,
            fetch: input.fetch,
            name: "experiment.assigned",
            eventId: assignmentId,
            anonymousId: input.anonymousId,
            sessionId: input.sessionId,
            experimentId: experiment.id,
            variantId: chosen.variant_id,
            assignmentVersion: experiment.assignment_version,
            placement: experiment.placement,
          })
          .then(function () {
            return {
              variant: chosen.role,
              experiment: experiment,
              variantId: chosen.variant_id,
            };
          })
          .catch(function () {
            return { variant: "CONTROL", reason: "telemetry_failure" };
          });
      })
      .catch(function () {
        return { variant: "CONTROL", reason: "network_failure" };
      });
  }

  return { start: start, CONTROL_COPY: CONTROL_COPY };
});
