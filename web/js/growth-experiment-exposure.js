(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.HIAIR_GROWTH_EXPOSURE = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var THRESHOLD = 0.5, MIN_DURATION_MS = 1000, CONTRACT_VERSION = "io-50pct-1000ms-v1";
  function conditionMet(ratio, visibleMs) { return Number.isFinite(ratio) && ratio >= THRESHOLD && ratio <= 1 && visibleMs >= MIN_DURATION_MS; }
  function exposureEventId(input) {
    return ["experiment.exposed", input.experimentId, input.variantId, input.anonymousId, input.placement, CONTRACT_VERSION].join(":");
  }
  function watchExposure(input) {
    var since = null, timer = null, inflight = false, sent = false, stopped = false, ratio = 0;
    var now = input.now || Date.now, schedule = input.setTimeout || setTimeout, cancel = input.clearTimeout || clearTimeout;
    function eligible() { return !stopped && (!input.isVisible || input.isVisible()) && ratio >= THRESHOLD && ratio <= 1; }
    function reset() { since = null; if (timer !== null) cancel(timer); timer = null; }
    function check() {
      timer = null;
      if (!eligible()) { reset(); return; }
      if (sent || inflight || since === null) return;
      var elapsed = now() - since;
      if (elapsed < MIN_DURATION_MS) { timer = schedule(check, MIN_DURATION_MS - elapsed); return; }
      inflight = true;
      var occurredAt = new Date(now()).toISOString();
      Promise.resolve().then(function () { return input.send(input.eventId || exposureEventId(input), occurredAt); }).then(function (receipt) {
        inflight = false;
        if (stopped) return;
        if (!receipt || receipt.ok !== true) throw new Error("exposure_unverified");
        sent = true; reset();
        if (input.onAcknowledged) input.onAcknowledged();
      }).catch(function () {
        inflight = false;
        if (stopped) return;
        reset();
        if (input.onFailure) input.onFailure();
      });
    }
    function onRatio(value) {
      ratio = Number.isFinite(value) ? value : 0;
      if (!eligible()) { reset(); return; }
      if (sent || inflight) return;
      if (since === null) since = now();
      if (timer !== null) cancel(timer);
      check();
    }
    return { onRatio: onRatio, reset: function () { ratio = 0; reset(); }, stop: function () { stopped = true; reset(); }, conditionMet: conditionMet };
  }
  return { THRESHOLD: THRESHOLD, MIN_DURATION_MS: MIN_DURATION_MS, CONTRACT_VERSION: CONTRACT_VERSION,
    conditionMet: conditionMet, exposureEventId: exposureEventId, watchExposure: watchExposure };
});
