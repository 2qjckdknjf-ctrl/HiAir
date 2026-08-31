(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.HIAIR_GROWTH_ASSIGNMENT = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  var STORAGE_PREFIX = "growth_experiment:";

  function sha256Hex(value) {
    var nodeCrypto = typeof require === "function" ? require("crypto") : null;
    if (nodeCrypto && typeof nodeCrypto.createHash === "function") {
      return nodeCrypto.createHash("sha256").update(value, "utf8").digest("hex");
    }
    return null;
  }

  function bucket(experimentId, assignmentVersion, anonymousId) {
    var hex = sha256Hex(experimentId + ":" + assignmentVersion + ":" + anonymousId);
    if (!hex) {
      return 0;
    }
    return parseInt(hex.slice(0, 12), 16) / 0x1000000000000;
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
    return allocation[0];
  }

  function assignFromHash(input) {
    var allocation = input.allocation || [];
    var fallback = controlVariant(allocation);
    if (!input.experimentId || !input.anonymousId || !input.assignmentVersion || !fallback) {
      return fallback
        ? { variant_id: fallback.variant_id, role: fallback.role, source: "control_fallback" }
        : null;
    }
    var total = 0;
    for (var i = 0; i < allocation.length; i += 1) {
      total += Number(allocation[i].weight) || 0;
    }
    if (total <= 0) {
      return { variant_id: fallback.variant_id, role: fallback.role, source: "control_fallback" };
    }
    var point = bucket(input.experimentId, input.assignmentVersion, input.anonymousId);
    var cursor = 0;
    for (var j = 0; j < allocation.length; j += 1) {
      cursor += (Number(allocation[j].weight) || 0) / total;
      if (point < cursor) {
        return { variant_id: allocation[j].variant_id, role: allocation[j].role, source: "hash" };
      }
    }
    var last = allocation[allocation.length - 1];
    return { variant_id: last.variant_id, role: last.role, source: "hash" };
  }

  function storageKey(experimentId, assignmentVersion) {
    return STORAGE_PREFIX + experimentId + ":" + assignmentVersion;
  }

  function readSticky(storage, experimentId, assignmentVersion) {
    try {
      var raw = storage.getItem(storageKey(experimentId, assignmentVersion));
      if (!raw) {
        return null;
      }
      var parsed = JSON.parse(raw);
      if (parsed && typeof parsed.variant_id === "string") {
        return parsed;
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  function writeSticky(storage, experimentId, assignmentVersion, variantId) {
    try {
      storage.setItem(
        storageKey(experimentId, assignmentVersion),
        JSON.stringify({ variant_id: variantId, assigned_at: new Date().toISOString() }),
      );
    } catch (error) {
      return;
    }
  }

  function assignVisitor(input) {
    var storage = input.storage;
    var hashed = assignFromHash(input);
    if (!hashed) {
      return null;
    }
    if (storage) {
      var sticky = readSticky(storage, input.experimentId, input.assignmentVersion);
      if (sticky && sticky.variant_id) {
        var known = (input.allocation || []).find(function (row) {
          return row.variant_id === sticky.variant_id;
        });
        if (known) {
          return { variant_id: known.variant_id, role: known.role, source: "sticky" };
        }
      }
      writeSticky(storage, input.experimentId, input.assignmentVersion, hashed.variant_id);
    }
    return hashed;
  }

  return {
    assignVisitor: assignVisitor,
    assignFromHash: assignFromHash,
    storageKey: storageKey,
  };
});
