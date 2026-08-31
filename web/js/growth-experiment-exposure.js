(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_EXPOSURE = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var THRESHOLD = 0.5;
  var MIN_DURATION_MS = 1000;
  var CONTRACT_VERSION = "io-50pct-1000ms-v1";

  function conditionMet(intersectionRatio, visibleMs) {
    return intersectionRatio >= THRESHOLD && visibleMs >= MIN_DURATION_MS;
  }

  function exposureEventId(input) {
    return [
      "experiment.exposed",
      input.experimentId,
      input.variantId,
      input.anonymousId,
      input.placement,
      CONTRACT_VERSION,
    ].join(":");
  }

  /**
   * Fake-timer friendly watcher. `now()` and `observe` are injected.
   * Does not mark an exposure as sent until `send()` resolves.
   */
  function watchExposure(input) {
    var visibleSince = null;
    var inflight = false;
    var sent = false;
    var now = input.now || function () {
      return Date.now();
    };
    var send = input.send;

    function onRatio(ratio) {
      if (sent || inflight) {
        return;
      }
      if (ratio < THRESHOLD) {
        visibleSince = null;
        return;
      }
      if (visibleSince == null) {
        visibleSince = now();
      }
      if (now() - visibleSince >= MIN_DURATION_MS) {
        inflight = true;
        Promise.resolve(send(exposureEventId(input)))
          .then(function () {
            sent = true;
            inflight = false;
          })
          .catch(function () {
            inflight = false;
          });
      }
    }

    return { onRatio: onRatio, conditionMet: conditionMet };
  }

  return {
    THRESHOLD: THRESHOLD,
    MIN_DURATION_MS: MIN_DURATION_MS,
    CONTRACT_VERSION: CONTRACT_VERSION,
    conditionMet: conditionMet,
    exposureEventId: exposureEventId,
    watchExposure: watchExposure,
  };
});
