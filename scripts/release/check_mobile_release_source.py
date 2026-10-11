#!/usr/bin/env python3
"""Fail mobile store delivery unless source is in main and API code matches it."""
import argparse
import io
import sys
import tarfile
import hashlib
import json
import ssl
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
from app.services.source_identity import hash_sources


def source_digest(sha, root=ROOT):
    archive=subprocess.check_output(['git','archive',sha,'backend/app'],cwd=root)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        return hash_sources((entry.name.removeprefix('backend/app/'),tar.extractfile(entry).read())
                            for entry in tar.getmembers() if entry.isfile() and entry.name.endswith('.py'))



def validate_source(source_sha, api_sha, root=ROOT):
    if not all(isinstance(value,str) and re.fullmatch(r'[0-9a-f]{40}', value) for value in (source_sha,api_sha)):
        raise ValueError('Source and API must report full immutable commit SHAs')
    for sha in (source_sha,api_sha):
        ancestor=subprocess.run(['git','merge-base','--is-ancestor',sha,'origin/main'],cwd=root,capture_output=True)
        if ancestor.returncode:
            raise ValueError('Mobile/API source is not reachable from origin/main')
    trees=[subprocess.check_output(['git','rev-parse',f'{sha}:backend'],cwd=root,text=True).strip()
           for sha in (source_sha,api_sha)]
    if trees[0]!=trees[1]:
        raise ValueError('Production backend code differs from the mobile release source; deploy first')
    return {'source_sha':source_sha,'api_sha':api_sha,'backend_tree':trees[0]}


def source_from_manifest(artifact, manifest, root=ROOT):
    data=json.loads(Path(manifest).read_text())
    artifact=Path(artifact).resolve()
    for entry in data.get('artifacts',[]):
        recorded=Path(entry['path'])
        if not recorded.is_absolute(): recorded=root/recorded
        if recorded.resolve()==artifact:
            if hashlib.sha256(artifact.read_bytes()).hexdigest()!=entry.get('sha256'):
                raise ValueError('Artifact hash differs from its release manifest')
            return entry.get('source_sha') or data.get('ios_source_sha') or data.get('source_sha')
    raise ValueError('Artifact is absent from its release manifest')


def validate_artifact_checkout(source_sha, checkout_sha, platform_path, root=ROOT):
    trees=[subprocess.check_output(['git','rev-parse',f'{sha}:{platform_path}'],cwd=root,text=True).strip()
           for sha in (source_sha,checkout_sha)]
    if trees[0]!=trees[1]:
        raise ValueError('Artifact mobile source differs from this checkout; rebuild before upload')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--artifact',type=Path)
    parser.add_argument('--manifest',type=Path)
    args=parser.parse_args()
    if bool(args.artifact)!=bool(args.manifest): parser.error('artifact and manifest must be provided together')
    checkout=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    source=checkout
    if args.artifact:
        try: source=source_from_manifest(args.artifact,args.manifest)
        except ValueError as error: raise SystemExit(str(error))
    try:
        import certifi
        context=ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        context=ssl.create_default_context()
    request=urllib.request.Request('https://api.hiair.io/api/health',headers={'User-Agent':'HiAir-Release-Preflight/1.0'})
    with urllib.request.urlopen(request,timeout=30,context=context) as response: health=json.load(response)
    if health.get('status')!='ok' or health.get('service')!='hiair-backend':
        raise SystemExit('Production API health is invalid')
    try:
        result=validate_source(source,health.get('deploy_git_sha'))
        if health.get('app_source_sha256') != source_digest(source):
            raise ValueError('Running application code does not match source; deployment/rollout is incomplete')
        result['app_source_sha256']=health['app_source_sha256']
        if args.artifact:
            platform='mobile/ios' if args.artifact.suffix=='.ipa' else 'mobile/android'
            validate_artifact_checkout(source,checkout,platform)
    except ValueError as error: raise SystemExit(str(error))
    print(json.dumps(result))
    return 0

if __name__=='__main__':
    raise SystemExit(main())
