(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.HIAIR_GROWTH_EXPERIMENT_CONFIG = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  var MAX_BYTES = 16384;
  function empty() { return { experiments: [] }; }
  function sanitizeCtaCopy(value) {
    if (typeof value !== "string") return null;
    var clipped = value.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 80);
    if (!clipped || clipped.indexOf("@") >= 0 || /<script/i.test(clipped) || /<\/?[a-z]/i.test(clipped) || /\beval\b/i.test(clipped)) return null;
    return clipped;
  }
  function publicConfig(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw) || Object.keys(raw).some(function (k) { return k !== "cta_copy"; })) return {};
    var copy = sanitizeCtaCopy(raw.cta_copy);
    return copy ? { cta_copy: copy } : {};
  }
  function validEndpoint(value) {
    try {
      var u = new URL(value);
      return !u.username && !u.password && !u.hash && (u.protocol === "https:" ||
        (u.protocol === "http:" && (u.hostname === "127.0.0.1" || u.hostname === "localhost")));
    } catch (_) { return false; }
  }
  // A single deadline covers headers and body. Browser streams are bounded before parsing.
  function requestJson(input) {
    return new Promise(function (resolve, reject) {
      if (!input || !validEndpoint(input.url) || typeof input.fetch !== "function" || typeof AbortController !== "function") {
        reject(new Error("transport_unavailable")); return;
      }
      if (input.method === "POST" && (typeof input.body !== "string" || typeof TextEncoder !== "function" ||
        new TextEncoder().encode(input.body).length > 8192)) { reject(new Error("request_too_large")); return; }
      var controller = new AbortController(), settled = false, timer;
      var external = input.signal;
      function finish(error, result) {
        if (settled) return;
        settled = true; clearTimeout(timer);
        if (external) external.removeEventListener("abort", abort);
        if (error) { controller.abort(); reject(error); } else resolve(result);
      }
      function abort() { finish(new Error("transport_stopped")); }
      if (external && external.aborted) { abort(); return; }
      if (external) external.addEventListener("abort", abort, { once: true });
      var timeout = Number.isFinite(input.timeoutMs) && input.timeoutMs > 0 ? Math.min(input.timeoutMs, 5000) : 5000;
      timer = setTimeout(function () { finish(new Error("transport_timeout")); }, timeout);
      function parse(text) {
        if (typeof text !== "string" || text.length > MAX_BYTES ||
          (typeof TextEncoder === "function" && new TextEncoder().encode(text).length > MAX_BYTES)) throw new Error("response_too_large");
        return JSON.parse(text);
      }
      function body(response) {
        var length = response.headers && response.headers.get("content-length");
        if (length && (!/^\d+$/.test(length) || Number(length) > MAX_BYTES)) throw new Error("response_too_large");
        if (response.body && typeof response.body.getReader === "function" && typeof TextDecoder === "function") {
          var reader = response.body.getReader(), decoder = new TextDecoder("utf-8", { fatal: true }), size = 0, text = "";
          function read() {
            return reader.read().then(function (chunk) {
              if (settled) { reader.cancel().catch(function () {}); throw new Error("transport_stopped"); }
              if (chunk.done) return parse(text + decoder.decode());
              size += chunk.value.byteLength;
              if (size > MAX_BYTES) { reader.cancel().catch(function () {}); throw new Error("response_too_large"); }
              text += decoder.decode(chunk.value, { stream: true }); return read();
            });
          }
          return read();
        }
        if (typeof response.text === "function") return response.text().then(parse);
        // Injected unit-test transports may implement json() without a browser stream.
        if (typeof response.json === "function") return response.json().then(function (value) { return parse(JSON.stringify(value)); });
        throw new Error("response_invalid");
      }
      Promise.resolve().then(function () {
        return input.fetch(input.url, { method: input.method || "GET", headers: Object.assign({ accept: "application/json" }, input.headers),
          body: input.body, keepalive: input.method === "POST", credentials: "omit", redirect: "error", cache: "no-store", signal: controller.signal });
      }).then(function (response) {
        if (!response || response.ok !== true) throw new Error("transport_rejected");
        return body(response).then(function (value) { return { status: response.status, body: value }; });
      }).then(function (result) { finish(null, result); }, function (error) { finish(error); });
    });
  }
  function validPayload(body, placement) {
    if (!body || !Array.isArray(body.experiments) || body.experiments.length !== 1) return empty();
    var e = body.experiments[0];
    if (!e || !UUID.test(e.id) || e.surface !== "website" || e.placement !== placement ||
      typeof e.assignment_version !== "string" || !/^[a-zA-Z0-9._:-]{1,128}$/.test(e.assignment_version) ||
      !Array.isArray(e.allocation) || e.allocation.length !== 2) return empty();
    var controls = 0, treatments = 0, ids = [], total = 0;
    for (var i = 0; i < e.allocation.length; i += 1) {
      var row = e.allocation[i];
      if (!row || !UUID.test(row.variant_id) || ids.indexOf(row.variant_id) !== -1 ||
        typeof row.weight !== "number" || !Number.isFinite(row.weight) || row.weight <= 0 || row.weight >= 1 ||
        !row.public_config || typeof row.public_config !== "object" || Array.isArray(row.public_config) ||
        Object.keys(row.public_config).some(function (k) { return k !== "cta_copy"; })) return empty();
      var sanitized = publicConfig(row.public_config);
      if (row.role === "CONTROL") controls += 1;
      else if (row.role === "TREATMENT" && sanitized.cta_copy) treatments += 1;
      else return empty();
      if (row.public_config.cta_copy !== undefined && sanitized.cta_copy !== row.public_config.cta_copy) return empty();
      total += row.weight; ids.push(row.variant_id);
    }
    if (controls !== 1 || treatments !== 1 || Math.abs(total - 1) >= 1e-9) return empty();
    return { experiments: [{ id: e.id, assignment_version: e.assignment_version, surface: "website", placement: placement,
      allocation: e.allocation.map(function (r) { return { variant_id: r.variant_id, role: r.role, weight: r.weight, public_config: publicConfig(r.public_config) }; }) }] };
  }
  function failClosedFetch(input) {
    if (!input || input.enabled !== true) return Promise.resolve(empty());
    return requestJson(input).then(function (response) {
      return response.status === 200 ? validPayload(response.body, input.placement || "header") : empty();
    }).catch(function () { return empty(); });
  }
  function applyCtaCopy(el, copy) {
    if (!el || typeof copy !== "string" || !copy) return false;
    el.textContent = copy; return el.textContent === copy;
  }
  return { empty: empty, publicConfig: publicConfig, validPayload: validPayload, validEndpoint: validEndpoint,
    requestJson: requestJson, failClosedFetch: failClosedFetch, applyCtaCopy: applyCtaCopy };
});
