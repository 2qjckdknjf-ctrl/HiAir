(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_EXPERIMENT = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var CONTROL_COPY = "Download on the App Store";

  function control(reason) {
    return { variant: "CONTROL", reason: reason };
  }

  function hasControl(allocation) {
    if (!allocation || !allocation.length) {
      return false;
    }
    for (var i = 0; i < allocation.length; i += 1) {
      if (allocation[i].role === "CONTROL") {
        return true;
      }
    }
    return false;
  }

  function start(input) {
    var enabled = Boolean(input && input.enabled);
    var configApi = (input && input.configApi) || {};
    var assignmentApi = (input && input.assignmentApi) || {};
    var telemetryApi = (input && input.telemetryApi) || {};
    if (!enabled) {
      return Promise.resolve(control("flag_off"));
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
        if (!experiment || !experiment.id || !experiment.assignment_version || !Array.isArray(experiment.allocation)) {
          return control("no_active_experiment");
        }
        if (!hasControl(experiment.allocation)) {
          return control("missing_control");
        }
        if (typeof assignmentApi.assignVisitor !== "function") {
          return control("assignment_failure");
        }
        return Promise.resolve(
          assignmentApi.assignVisitor({
            experimentId: experiment.id,
            assignmentVersion: experiment.assignment_version,
            anonymousId: input.anonymousId,
            allocation: experiment.allocation,
            storage: input.storage,
          }),
        ).then(function (assigned) {
          if (!assigned || !assigned.variant_id) {
            return control("assignment_failure");
          }
          var chosen = (experiment.allocation || []).find(function (row) {
            return row.variant_id === assigned.variant_id;
          });
          if (!chosen) {
            return control("bad_variant");
          }
          if (chosen.role === "TREATMENT") {
            var sanitized = configApi.publicConfig ? configApi.publicConfig(chosen.public_config) : {};
            if (!sanitized || !sanitized.cta_copy) {
              return control("invalid_treatment_config");
            }
            if (input.ctaEl) {
              configApi.applyCtaCopy(input.ctaEl, sanitized.cta_copy);
            }
          } else if (input.ctaEl && !input.ctaEl.textContent) {
            input.ctaEl.textContent = CONTROL_COPY;
          }
          if (!telemetryApi || typeof telemetryApi.send !== "function") {
            return { variant: chosen.role, experiment: experiment, variantId: chosen.variant_id };
          }
          var assignmentId = telemetryApi.assignmentEventId
            ? telemetryApi.assignmentEventId(experiment.id, input.anonymousId, experiment.assignment_version)
            : ["experiment.assigned", experiment.id, input.anonymousId, experiment.assignment_version].join(":");
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
              return control("telemetry_failure");
            });
        });
      })
      .catch(function () {
        return control("network_failure");
      });
  }

  return { start: start, CONTROL_COPY: CONTROL_COPY };
});
