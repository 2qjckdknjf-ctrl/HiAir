#!/usr/bin/env python3
"""Read-only checks that prevent starting HiAir work from a stale or dirty copy."""
import argparse
import json
import subprocess
from pathlib import Path


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--task', help='Existing ID from the delivery registry')
    parser.add_argument('--resume', action='store_true', help='Resume the registered implementation')
    args = parser.parse_args()
    root = Path(git('rev-parse', '--show-toplevel'))
    registry = json.loads((root / 'docs/_operator/DELIVERY_REGISTRY.json').read_text())
    tasks = registry['tasks']
    ids = [t['id'] for t in tasks]
    if len(ids) != len(set(ids)):
        raise SystemExit('ERROR: duplicate task IDs in delivery registry')
    branch = git('branch', '--show-current')
    head = git('rev-parse', 'HEAD')
    upstream = git('rev-parse', 'origin/main')
    print(f'checkout={root}\nbranch={branch}\nhead={head}\norigin/main={upstream}')
    if git('status', '--porcelain'):
        raise SystemExit('ERROR: working copy is dirty; preserve it before starting another task')
    if branch == 'main' and head != upstream:
        raise SystemExit('ERROR: local main differs from origin/main; reconcile before starting')
    if branch != 'main' and subprocess.run(['git', 'merge-base', '--is-ancestor', upstream, 'HEAD'], capture_output=True).returncode:
        raise SystemExit('ERROR: branch does not contain current origin/main')
    if args.task:
        task = next((t for t in tasks if t['id'] == args.task), None)
        if not task:
            raise SystemExit('ERROR: register a new task and check existing implementations first')
        print(f"task={task['id']} status={task['status']} existing={task['existing_implementation']}")
        if task['status'] == 'KEEP_FOR_LATER':
            raise SystemExit('ERROR: deferred by the current plan; do not expand the release')
        if task['status'] != 'NEEDS_NEW_CODE' and not args.resume:
            raise SystemExit('ERROR: existing implementation found; use --resume for its remaining work')
    print('PASS: explicit source and registry established; read open PRs before editing')


if __name__ == '__main__':
    main()
