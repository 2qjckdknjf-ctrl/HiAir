#!/usr/bin/env bash
# Resolve and boot a specific iOS Simulator by name or UDID.
set -euo pipefail

REQUESTED_NAME="${1:-iPhone 17 Pro}"
REQUESTED_RUNTIME="${IOS_SIMULATOR_RUNTIME:-}" # optional filter e.g. iOS-26-2
REQUESTED_UDID="${IOS_SIMULATOR_UDID:-}"

python3 - <<'PY' "${REQUESTED_NAME}" "${REQUESTED_RUNTIME}" "${REQUESTED_UDID}"
import json, subprocess, sys

name, runtime_filter, forced_udid = sys.argv[1:4]

def simctl_json(*args):
    out = subprocess.check_output(["xcrun", "simctl", "list", *args, "-j"], text=True)
    return json.loads(out)

if forced_udid:
    udid = forced_udid
else:
    data = simctl_json("devices", "available")
    matches = []
    for runtime, devices in data.get("devices", {}).items():
        if runtime_filter and runtime_filter not in runtime:
            continue
        for dev in devices:
            if not dev.get("isAvailable"):
                continue
            if dev.get("name") == name:
                matches.append((runtime, dev))
    if not matches:
        raise SystemExit(f"No available simulator named {name!r}")
    # Prefer newest runtime when duplicates exist.
    matches.sort(key=lambda item: item[0], reverse=True)
    runtime, dev = matches[0]
    udid = dev["udid"]
    name = dev["name"]

info = simctl_json("devices")
runtime_id = None
runtime_version = None
device_name = name
for runtime, devices in info.get("devices", {}).items():
    for dev in devices:
        if dev.get("udid") == udid:
            runtime_id = runtime
            device_name = dev.get("name", name)
            if "iOS-" in runtime:
                runtime_version = runtime.split("iOS-")[-1].replace("-", ".")
            break
    if runtime_id:
        break

subprocess.run(["xcrun", "simctl", "boot", udid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
boot = subprocess.run(
    ["xcrun", "simctl", "bootstatus", udid, "-b"],
    check=True,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.PIPE,
    text=True,
)
if boot.stderr:
    print(boot.stderr, file=sys.stderr, end="")

print(json.dumps({
    "udid": udid,
    "name": device_name,
    "runtime_identifier": runtime_id,
    "runtime_version": runtime_version,
    "destination": f"platform=iOS Simulator,id={udid}",
}))
PY
