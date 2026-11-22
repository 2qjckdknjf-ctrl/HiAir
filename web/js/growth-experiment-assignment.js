(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_ASSIGNMENT = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var STORAGE_PREFIX = "growth_experiment:";
  var BUCKET_DIVISOR = 0x1000000000000;

  function webCrypto() {
    return typeof globalThis !== "undefined" && globalThis.crypto ? globalThis.crypto : null;
  }

  function bytesToHex(buffer) {
    var view = new Uint8Array(buffer);
    var hex = "";
    for (var i = 0; i < view.length; i += 1) {
      var part = view[i].toString(16);
      hex += part.length === 1 ? "0" + part : part;
    }
    return hex;
  }

  /**
   * Browser-native SHA-256. Never uses CommonJS require("crypto").
   * Returns null when Web Crypto is missing or throws (fail closed).
   */
  function sha256Hex(value) {
    var cryptoObj, bytes;
    try {
      cryptoObj = webCrypto();
      if (!cryptoObj || !cryptoObj.subtle || typeof cryptoObj.subtle.digest !== "function" || typeof TextEncoder !== "function") return Promise.resolve(null);
      bytes = new TextEncoder().encode(value);
    } catch (_) { return Promise.resolve(null); }
    return Promise.resolve().then(function () { return cryptoObj.subtle.digest("SHA-256", bytes); }).then(bytesToHex).catch(function () {
      return null;
    });
  }

  function bucketFromHex(hex) {
    if (typeof hex !== "string" || !/^[a-f0-9]{64}$/.test(hex)) {
      return null;
    }
    var bits = parseInt(hex.slice(0, 12), 16);
    if (!isFinite(bits)) {
      return null;
    }
    return bits / BUCKET_DIVISOR;
  }

  function controlVariant(allocation) {
    if (!allocation || !allocation.length) {
      return null;
    }
    for (var i = 0; i < allocation.length; i += 1) {
      if (allocation[i].role === "CONTROL") {
        return allocation[i];
      }
    }
    return null;
  }

  function findVariant(allocation, variantId) {
    if (!allocation || !variantId) {
      return null;
    }
    for (var i = 0; i < allocation.length; i += 1) {
      if (allocation[i].variant_id === variantId) {
        return allocation[i];
      }
    }
    return null;
  }

  function controlResult(allocation, reason) {
    var fallback = controlVariant(allocation);
    if (!fallback) {
      return null;
    }
    return {
      variant_id: fallback.variant_id,
      role: "CONTROL",
      source: "control_fallback",
      reason: reason || "control_fallback",
      bucket: null,
    };
  }

  function assignFromHash(input) {
    var allocation = (input && input.allocation) || [];
    if (!input || !input.experimentId || !input.anonymousId || !input.assignmentVersion) {
      return Promise.resolve(controlResult(allocation, "missing_identity"));
    }
    if (!controlVariant(allocation)) {
      return Promise.resolve(controlResult(allocation, "missing_control"));
    }
    var total = 0;
    for (var i = 0; i < allocation.length; i += 1) {
      var weight = Number(allocation[i].weight);
      if (!isFinite(weight) || weight < 0) {
        return Promise.resolve(controlResult(allocation, "invalid_weight"));
      }
      total += weight;
    }
    if (total <= 0) {
      return Promise.resolve(controlResult(allocation, "invalid_allocation"));
    }
    var material = input.experimentId + ":" + input.assignmentVersion + ":" + input.anonymousId;
    return sha256Hex(material).then(function (hex) {
      var point = bucketFromHex(hex);
      if (point == null) {
        return controlResult(allocation, "crypto_unavailable");
      }
      var cursor = 0;
      for (var j = 0; j < allocation.length; j += 1) {
        cursor += Number(allocation[j].weight) / total;
        if (point < cursor) {
          var chosen = allocation[j];
          if (chosen.role !== "CONTROL" && chosen.role !== "TREATMENT") {
            return controlResult(allocation, "invalid_role");
          }
          return {
            variant_id: chosen.variant_id,
            role: chosen.role,
            source: "hash",
            bucket: point,
            sha256_prefix: hex.slice(0, 12),
          };
        }
      }
      var last = allocation[allocation.length - 1];
      if (!last || (last.role !== "CONTROL" && last.role !== "TREATMENT")) {
        return controlResult(allocation, "invalid_role");
      }
      return {
        variant_id: last.variant_id,
        role: last.role,
        source: "hash",
        bucket: point,
        sha256_prefix: hex.slice(0, 12),
      };
    });
  }

  function storageKey(experimentId, assignmentVersion, anonymousId) {
    return STORAGE_PREFIX + experimentId + ":" + assignmentVersion + ":" + (anonymousId || "");
  }

  function parseSticky(raw, experimentId, assignmentVersion, anonymousId, allocation) {
    if (!raw) {
      return null;
    }
    var parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (error) {
      return null;
    }
    if (!parsed || typeof parsed.variant_id !== "string") {
      return null;
    }
    if (parsed.experiment_id !== experimentId || parsed.anonymous_id !== anonymousId) {
      return null;
    }
    if (parsed.assignment_version !== assignmentVersion) {
      return null;
    }
    var known = findVariant(allocation, parsed.variant_id);
    if (!known) {
      return null;
    }
    if (known.role !== "CONTROL" && known.role !== "TREATMENT") {
      return null;
    }
    return known;
  }

  function readSticky(storage, experimentId, assignmentVersion, anonymousId, allocation) {
    if (!storage || typeof storage.getItem !== "function") {
      return null;
    }
    try {
      return parseSticky(storage.getItem(storageKey(experimentId, assignmentVersion, anonymousId)), experimentId, assignmentVersion, anonymousId, allocation);
    } catch (error) {
      return null;
    }
  }

  function writeSticky(storage, experimentId, assignmentVersion, anonymousId, variantId) {
    if (!storage || typeof storage.setItem !== "function" || typeof storage.getItem !== "function") {
      return false;
    }
    var key = storageKey(experimentId, assignmentVersion, anonymousId);
    var payload = JSON.stringify({
      variant_id: variantId,
      assigned_at: new Date().toISOString(),
      anonymous_id: anonymousId,
      experiment_id: experimentId,
      assignment_version: assignmentVersion,
    });
    try {
      storage.setItem(key, payload);
      var raw = storage.getItem(key);
      if (!raw) {
        return false;
      }
      var parsed = JSON.parse(raw);
      return parsed && parsed.variant_id === variantId && parsed.anonymous_id === anonymousId && parsed.experiment_id === experimentId && parsed.assignment_version === assignmentVersion;
    } catch (error) {
      return false;
    }
  }

  /**
   * Visitor assignment. Treatment requires durable stickiness.
   * Missing storage, write failure, or crypto failure → CONTROL.
   */
  function assignVisitor(input) {
    var allocation = (input && input.allocation) || [];
    var storage = input && input.storage;
    if (!storage || typeof storage.getItem !== "function" || typeof storage.setItem !== "function") {
      return Promise.resolve(controlResult(allocation, "storage_unavailable"));
    }
    if (typeof input.anonymousId !== "string" || !input.anonymousId || input.anonymousId.length > 128 ||
      typeof input.sessionId === "string" && input.sessionId.length > 128) return Promise.resolve(controlResult(allocation, "missing_identity"));
    // Recheck crypto even for cached assignments: a stale treatment cannot bypass a failed prerequisite.
    return assignFromHash(input).then(function (hashed) {
      if (!hashed || hashed.source !== "hash") return hashed || controlResult(allocation, "assignment_failure");
      var sticky = readSticky(storage, input.experimentId, input.assignmentVersion, input.anonymousId, allocation);
      var chosen = sticky || { variant_id: hashed.variant_id, role: hashed.role };
      if (!writeSticky(storage, input.experimentId, input.assignmentVersion, input.anonymousId, chosen.variant_id)) {
        return controlResult(allocation, "storage_write_failure");
      }
      return { variant_id: chosen.variant_id, role: chosen.role, source: sticky ? "sticky" : "hash",
        bucket: hashed.bucket, sha256_prefix: hashed.sha256_prefix };
    }).catch(function () { return controlResult(allocation, "assignment_failure"); });
  }

  return {
    assignVisitor: assignVisitor,
    assignFromHash: assignFromHash,
    storageKey: storageKey,
    sha256Hex: sha256Hex,
    bucketFromHex: bucketFromHex,
  };
});
