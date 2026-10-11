#!/usr/bin/env python3
"""Keep required CI checks present while avoiding unchanged-domain rebuilds."""
import argparse
import os
import subprocess

SCOPES = {
    'backend': ('backend/', 'scripts/release/', 'scripts/ops/deploy_hiair_api_cloudflare.sh', '.github/workflows/backend-ci.yml'),
    'android': ('mobile/android/', 'scripts/ops/run_android', '.github/workflows/android-ci.yml'),
    'ios': ('mobile/ios/', '.github/workflows/ios-ci.yml'),
}


def requires_validation(scope, paths):
    return any(path.startswith(('scripts/ci/',) + SCOPES[scope]) for path in paths)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--scope', choices=SCOPES, required=True)
    p.add_argument('--base', default='')
    p.add_argument('--head', default='HEAD')
    args = p.parse_args()
    run = True
    if args.base and args.base.strip('0'):
        diff = subprocess.run(['git', 'diff', '--name-only', args.base, args.head], capture_output=True, text=True)
        if diff.returncode == 0:
            run = requires_validation(args.scope, diff.stdout.splitlines())
        else:
            print('Unable to prove scope; validate conservatively.')
    value = str(run).lower()
    print(f'{args.scope}: run={value}')
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a') as f:
            f.write(f'run={value}\n')


if __name__ == '__main__':
    main()
