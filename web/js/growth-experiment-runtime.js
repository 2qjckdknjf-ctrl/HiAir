(function (root, factory) {
  var api = factory(root);
  if (typeof module === "object" && module.exports) module.exports = api;
  root.HIAIR_GROWTH_EXPERIMENT = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function (root) {
  var current = null, generation = 0;
  function control(reason) { return { variant: "CONTROL", reason: reason }; }
  function stop(reason) {
    generation += 1;
    var s = current; current = null;
    if (s) {
      s.controller.abort();
      if (s.watcher) s.watcher.stop();
      if (s.observer) s.observer.disconnect();
      if (s.mutations) s.mutations.disconnect();
      if (s.doc && s.visibility) s.doc.removeEventListener("visibilitychange", s.visibility);
      if (s.win && typeof s.win.removeEventListener === "function" && s.identityChanged) s.win.removeEventListener("storage", s.identityChanged);
      if (s.win && typeof s.win.removeEventListener === "function" && s.pagehide) s.win.removeEventListener("pagehide", s.pagehide);
      if (s.win && typeof s.win.removeEventListener === "function" && s.pageshow) s.win.removeEventListener("pageshow", s.pageshow);
      if (s.applied) s.el.textContent = s.original;
    }
    return control(reason || "stopped");
  }
  function sameIdentity(s) {
    try {
      var now = s.input.identity ? s.input.identity() : { anonymousId: s.input.anonymousId, sessionId: s.input.sessionId };
      return now && now.anonymousId === s.input.anonymousId && now.sessionId === s.input.sessionId;
    } catch (_) { return false; }
  }
  function live(s) {
    if (current !== s || generation !== s.generation) return false;
    if (!sameIdentity(s) || s.el.isConnected === false) { stop("identity_or_element_changed"); return false; }
    return true;
  }
  function getAttribution(placement, anonymousId, sessionId) {
    var s = current;
    if (!s || !live(s) || s.suspended || !s.exposed || placement !== s.input.placement || anonymousId !== s.input.anonymousId || sessionId !== s.input.sessionId) return null;
    return { experimentId: s.experiment.id, variantId: s.chosen.variant_id, assignmentVersion: s.experiment.assignment_version,
      placement: placement, eventId: s.clickId, generation: s.generation };
  }
  function rejectAttribution(context) {
    if (current && context && context.generation === current.generation && context.eventId === current.clickId) stop("click_unverified");
  }
  function start(input) {
    stop("reinitialized");
    if (!input || input.enabled !== true) return Promise.resolve(control("flag_off"));
    var config = input.configApi || root.HIAIR_GROWTH_EXPERIMENT_CONFIG;
    var assignment = input.assignmentApi || root.HIAIR_GROWTH_ASSIGNMENT;
    var telemetry = input.telemetryApi || root.HIAIR_GROWTH_EXPERIMENT_TELEMETRY;
    var exposure = input.exposureApi || root.HIAIR_GROWTH_EXPOSURE;
    var doc = input.document || root.document, win = input.window || root;
    var IO = input.IntersectionObserver || root.IntersectionObserver;
    var MO = input.MutationObserver || root.MutationObserver;
    var el = input.ctaEl;
    if (!config || !assignment || !telemetry || !exposure || !doc || typeof doc.addEventListener !== "function" ||
      typeof IO !== "function" || typeof MO !== "function" || typeof AbortController !== "function" ||
      !el || typeof el.textContent !== "string" || el.childElementCount > 0 || el.isConnected === false || input.placement !== "header" ||
      typeof input.anonymousId !== "string" || !input.anonymousId || input.anonymousId.length > 128 ||
      typeof input.sessionId !== "string" || !input.sessionId || input.sessionId.length > 128 ||
      !config.validEndpoint(input.eventsUrl) || !config.validEndpoint(input.configUrl)) return Promise.resolve(control("prerequisite_unavailable"));
    var s = { generation: generation, input: input, doc: doc, win: win, el: el, original: el.textContent,
      controller: new AbortController(), applied: false, exposed: false, suspended: false };
    current = s;
    function active() { return live(s); }
    function send(name, id, occurredAt) {
      if (!active()) return Promise.reject(new Error("stopped"));
      return telemetry.send({ configApi: config, url: input.eventsUrl, fetch: input.fetch, timeoutMs: input.timeoutMs, signal: s.controller.signal,
        name: name, eventId: id, occurredAt: occurredAt, anonymousId: input.anonymousId, sessionId: input.sessionId,
        experimentId: s.experiment.id, variantId: s.chosen.variant_id, assignmentVersion: s.experiment.assignment_version, placement: input.placement });
    }
    s.identityChanged = function () { if (current === s && !sameIdentity(s)) stop("identity_changed"); };
    // An initiated conversion has its own bounded keepalive transport. Suspend measurement
    // while cached; the frozen interval must never count as continuous visibility.
    s.pagehide = function (event) {
      if (current !== s) return;
      if (event && event.persisted) {
        s.suspended = true;
        if (s.watcher) s.watcher.reset();
        if (s.observer) s.observer.unobserve(el);
      } else stop("page_hidden");
    };
    s.pageshow = function (event) {
      if (current !== s || !s.suspended || !event || !event.persisted) return;
      if (!live(s)) return;
      // A cached page must not revive a stopped experiment or stale attribution.
      return start(input);
    };
    if (win && typeof win.addEventListener === "function") {
      win.addEventListener("storage", s.identityChanged); win.addEventListener("pagehide", s.pagehide);
      win.addEventListener("pageshow", s.pageshow);
    }
    return Promise.resolve().then(function () {
      return config.failClosedFetch({ enabled: true, url: input.configUrl, fetch: input.fetch, placement: input.placement,
        timeoutMs: input.timeoutMs, signal: s.controller.signal });
    }).then(function (payload) {
      if (!active()) throw new Error("stopped");
      var checked = config.validPayload(payload, input.placement);
      if (!checked.experiments.length) throw new Error("no_active_experiment");
      s.experiment = checked.experiments[0];
      return assignment.assignVisitor({ experimentId: s.experiment.id, assignmentVersion: s.experiment.assignment_version,
        anonymousId: input.anonymousId, sessionId: input.sessionId, allocation: s.experiment.allocation, storage: input.storage });
    }).then(function (assigned) {
      if (!active()) throw new Error("stopped");
      if (!assigned || (assigned.source !== "hash" && assigned.source !== "sticky")) throw new Error("assignment_failure");
      s.chosen = s.experiment.allocation.find(function (r) { return r.variant_id === assigned.variant_id && r.role === assigned.role; });
      if (!s.chosen) throw new Error("assignment_failure");
      var base = JSON.stringify([s.experiment.id, s.chosen.variant_id, s.experiment.assignment_version, input.anonymousId, input.placement]);
      return Promise.all([
        assignment.sha256Hex("assignment:" + base),
        assignment.sha256Hex("exposure:" + base + ":" + exposure.CONTRACT_VERSION),
        assignment.sha256Hex("click:" + base + ":" + input.sessionId)
      ]);
    }).then(function (hashes) {
      if (!active()) throw new Error("stopped");
      if (hashes.some(function (h) { return typeof h !== "string" || !/^[a-f0-9]{64}$/.test(h); })) throw new Error("crypto_unavailable");
      s.exposureId = "experiment.exposed:" + hashes[1]; s.clickId = "app_store_cta.clicked:" + hashes[2];
      return send("experiment.assigned", "experiment.assigned:" + hashes[0], new Date().toISOString());
    }).then(function (receipt) {
      if (!active()) throw new Error("stopped");
      if (!receipt || receipt.ok !== true) throw new Error("assignment_unverified");
      if (s.chosen.role === "TREATMENT") {
        var copy = config.publicConfig(s.chosen.public_config).cta_copy;
        if (!copy || copy === s.original) throw new Error("invalid_treatment_config");
        // Mark ownership before mutation so every failure restores the exact original text.
        s.applied = true;
        if (!config.applyCtaCopy(el, copy)) throw new Error("treatment_not_applied");
      }
      s.watcher = exposure.watchExposure({ eventId: s.exposureId,
        isVisible: function () { return active() && !s.suspended && doc.visibilityState === "visible" && doc.hidden !== true; },
        send: function (id, at) { return send("experiment.exposed", id, at); },
        onAcknowledged: function () { if (active()) s.exposed = true; },
        onFailure: function () { if (current === s) stop("exposure_unverified"); } });
      s.observer = new IO(function (entries) {
        if (!active() || s.suspended) return;
        entries.forEach(function (entry) {
          if (entry.target === el) s.watcher.onRatio(entry.isIntersecting === false ? 0 : entry.intersectionRatio);
        });
      }, { threshold: [0, exposure.THRESHOLD, 1] });
      s.visibility = function () {
        if (!active()) return;
        s.watcher.reset();
        s.observer.unobserve(el);
        if (!s.suspended && doc.visibilityState === "visible" && doc.hidden !== true) s.observer.observe(el);
      };
      doc.addEventListener("visibilitychange", s.visibility);
      s.mutations = new MO(function () { active(); });
      s.mutations.observe(doc.documentElement, { childList: true, subtree: true });
      if (!s.suspended) s.observer.observe(el);
      return { variant: s.chosen.role, experiment: s.experiment, variantId: s.chosen.variant_id };
    }).catch(function (error) {
      if (current === s) return stop(error && error.message || "runtime_failure");
      return control("stopped");
    });
  }
  return { start: start, stop: stop, getAttribution: getAttribution, rejectAttribution: rejectAttribution };
});
