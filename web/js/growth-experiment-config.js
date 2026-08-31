(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_EXPERIMENT_CONFIG = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function empty() {
    return { experiments: [] };
  }

  function sanitizeCtaCopy(value) {
    if (typeof value !== "string") {
      return null;
    }
    var clipped = value.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 80);
    if (!clipped || clipped.indexOf("@") >= 0 || /<script/i.test(clipped) || /<\/?[a-z]/i.test(clipped) || /\beval\b/i.test(clipped)) {
      return null;
    }
    return clipped;
  }

  function publicConfig(raw) {
    var copy = sanitizeCtaCopy(raw && raw.cta_copy);
    return copy ? { cta_copy: copy } : {};
  }

  function failClosedFetch(input) {
    if (!input.enabled) {
      return Promise.resolve(empty());
    }
    if (!input.url || !input.fetch) {
      return Promise.resolve(empty());
    }
    return input
      .fetch(input.url, { method: "GET", headers: { accept: "application/json" } })
      .then(function (response) {
        if (!response || !response.ok) {
          return empty();
        }
        return response.json();
      })
      .then(function (body) {
        if (!body || !Array.isArray(body.experiments)) {
          return empty();
        }
        return body;
      })
      .catch(function () {
        return empty();
      });
  }

  function applyCtaCopy(el, copy) {
    if (!el || !copy) {
      return false;
    }
    el.textContent = copy;
    return true;
  }

  return {
    empty: empty,
    publicConfig: publicConfig,
    failClosedFetch: failClosedFetch,
    applyCtaCopy: applyCtaCopy,
  };
});
