#!/usr/bin/env python3
"""Select/boot a concrete simulator and certify an actually completed unit run."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
from uuid import UUID, uuid4


def select_device(inventory):
    devices = [d for group in inventory.get('devices', {}).values() for d in group
               if d.get('isAvailable') and d.get('name', '').startswith('iPhone')]
    if not devices:
        raise ValueError('No available iPhone simulator; cannot execute required tests')
    return min(devices, key=lambda d: (d.get('state') != 'Booted', d['name'] != 'iPhone 17', d['name'], d['udid']))


def verify_summary(summary):
    total = summary.get('totalTestCount', 0)
    if (total <= 0 or summary.get('passedTests') != total or summary.get('failedTests') != 0
            or summary.get('skippedTests') != 0):
        raise ValueError('Unit run not certified: require executed tests, all passed, zero failed/skipped')
    return total


def create_fresh_device(inventory, selected):
    """Avoid migrating the runner image's existing device data; keep its type/runtime."""
    runtime = next((runtime for runtime, devices in inventory.get('devices', {}).items()
                    if any(device.get('udid') == selected['udid'] for device in devices)), None)
    device_type = selected.get('deviceTypeIdentifier')
    if not runtime or not device_type:
        raise ValueError('Cannot create a matching fresh simulator without runtime and device type')
    identifier = subprocess.check_output(['xcrun', 'simctl', 'create',
        f'HiAir-CI-{uuid4().hex[:8]}', device_type, runtime], text=True, timeout=30).strip()
    UUID(identifier)  # Reject malformed output rather than targeting an existing device.
    return {**selected, 'udid': identifier, 'state': 'Shutdown'}


def _shutdown_delete(udid):
    """Best-effort cleanup of a stuck disposable simulator."""
    for command in (
        ['xcrun', 'simctl', 'shutdown', udid],
        ['xcrun', 'simctl', 'delete', udid],
    ):
        subprocess.run(command, stdout=sys.stderr, stderr=sys.stderr, timeout=30, check=False)


def boot_device(device, *, boot_timeout=30, ready_timeout=300):
    """Boot and wait until ready. Does not weaken unit-run certification."""
    if device.get('state') != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True,
            stdout=sys.stderr, stderr=sys.stderr, timeout=boot_timeout)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'], check=True,
        stdout=sys.stderr, stderr=sys.stderr, timeout=ready_timeout)
    return {**device, 'state': 'Booted'}


def prepare_device(inventory, *, fresh=False, boot_attempts=2):
    """Select (optionally create) a simulator and boot with one infrastructure retry."""
    template = select_device(inventory)
    last_error = None
    for attempt in range(1, boot_attempts + 1):
        device = create_fresh_device(inventory, template) if fresh else template
        try:
            return boot_device(device)
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
            last_error = error
            print(f'simulator boot attempt {attempt}/{boot_attempts} failed: {error}', file=sys.stderr)
            subprocess.run(['xcrun', 'simctl', 'list', 'devices', 'available'],
                stdout=sys.stderr, stderr=sys.stderr, timeout=30, check=False)
            if fresh:
                _shutdown_delete(device['udid'])
            if attempt >= boot_attempts:
                raise
            if not fresh:
                # Existing device stuck: next attempt needs a disposable twin.
                fresh = True
    raise RuntimeError('simulator prepare exhausted without result')  # pragma: no cover


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'verify'])
    parser.add_argument('--select-only', action='store_true')
    parser.add_argument('--fresh', action='store_true', help='Create a matching disposable CI simulator')
    parser.add_argument('--result', type=Path)
    args = parser.parse_args()
    if args.mode == 'verify':
        if args.result is None or not args.result.exists():
            raise ValueError('A saved xcresult is required')
        summary = json.loads(subprocess.check_output(['xcrun', 'xcresulttool', 'get', 'test-results',
            'summary', '--path', str(args.result), '--compact'], text=True))
        print(f'Certified full unit run: {verify_summary(summary)} passed, zero failed/skipped')
        return
    inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True))
    if args.select_only:
        device = select_device(inventory)
    else:
        device = prepare_device(inventory, fresh=args.fresh)
    print(f"platform=iOS Simulator,id={device['udid']}")


if __name__ == '__main__':
    main()
