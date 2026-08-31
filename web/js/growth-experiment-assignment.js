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
    var cryptoObj = webCrypto();
    if (!cryptoObj || !cryptoObj.subtle || typeof cryptoObj.subtle.digest !== "function") {
      return Promise.resolve(null);
    }
    if (typeof TextEncoder !== "function") {
      return Promise.resolve(null);
    }
    var bytes;
    try {
      bytes = new TextEncoder().encode(value);
    } catch (error) {
      return Promise.resolve(null);
    }
    return cryptoObj.subtle.digest("SHA-256", bytes).then(bytesToHex).catch(function () {
      return null;
    });
  }

  function bucketFromHex(hex) {
    if (!hex || typeof hex !== "string" || hex.length < 12) {
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

  function storageKey(experimentId, assignmentVersion) {
    return STORAGE_PREFIX + experimentId + ":" + assignmentVersion;
  }

  function parseSticky(raw, experimentId, assignmentVersion, allocation) {
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
    if (parsed.experiment_id && parsed.experiment_id !== experimentId) {
      return null;
    }
    if (parsed.assignment_version && parsed.assignment_version !== assignmentVersion) {
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

  function readSticky(storage, experimentId, assignmentVersion, allocation) {
    if (!storage || typeof storage.getItem !== "function") {
      return null;
    }
    try {
      return parseSticky(storage.getItem(storageKey(experimentId, assignmentVersion)), experimentId, assignmentVersion, allocation);
    } catch (error) {
      return null;
    }
  }

  function writeSticky(storage, experimentId, assignmentVersion, variantId) {
    if (!storage || typeof storage.setItem !== "function" || typeof storage.getItem !== "function") {
      return false;
    }
    var key = storageKey(experimentId, assignmentVersion);
    var payload = JSON.stringify({
      variant_id: variantId,
      assigned_at: new Date().toISOString(),
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
      return parsed && parsed.variant_id === variantId;
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
    var sticky = readSticky(storage, input.experimentId, input.assignmentVersion, allocation);
    if (sticky) {
      return Promise.resolve({
        variant_id: sticky.variant_id,
        role: sticky.role,
        source: "sticky",
      });
    }
    return assignFromHash(input).then(function (hashed) {
      if (!hashed) {
        return controlResult(allocation, "assignment_failure");
      }
      if (hashed.source !== "hash") {
        return hashed;
      }
      if (!writeSticky(storage, input.experimentId, input.assignmentVersion, hashed.variant_id)) {
        return controlResult(allocation, "storage_write_failure");
      }
      return hashed;
    });
  }

  return {
    assignVisitor: assignVisitor,
    assignFromHash: assignFromHash,
    storageKey: storageKey,
    sha256Hex: sha256Hex,
    bucketFromHex: bucketFromHex,
  };
});
