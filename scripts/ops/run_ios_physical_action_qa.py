#!/usr/bin/env python3
"""Build/run the live ACTION UI check on a physical iPhone, without debug mocks."""
import argparse
import json
import subprocess
import ssl
import certifi
import urllib.request
import uuid
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / 'mobile/ios'


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('mode', choices=['build','test'])
    parser.add_argument('--device', required=True)
    parser.add_argument('--derived-data', type=Path, default=ROOT/'.evidence/action-device-derived')
    parser.add_argument('--expect-sha')
    parser.add_argument('--result', type=Path, default=ROOT/'.evidence/action-physical-tests.xcresult')
    args=parser.parse_args()
    derived=args.derived_data.resolve()
    destination=f'platform=iOS,id={args.device}'
    if args.mode=='build':
        directory=IOS/'HiAir.xcodeproj/xcshareddata/xcschemes'
        scheme='HiAirPhysicalQA_'+uuid.uuid4().hex[:8]
        temporary=directory/(scheme+'.xcscheme')
        tree=ET.parse(directory/'HiAir.xcscheme')
        for parent_path,child_name in [('BuildAction/BuildActionEntries','BuildActionEntry'),('TestAction/Testables','TestableReference')]:
            parent=tree.find(parent_path)
            for child in list(parent):
                reference=child.find('BuildableReference')
                if reference is not None and reference.get('BlueprintName')=='HiAirTests':
                    parent.remove(child)
        action=tree.find('TestAction')
        action.set('buildConfiguration','Release')
        action.set('shouldUseLaunchSchemeArgsEnv','NO')
        variables=ET.SubElement(action,'EnvironmentVariables')
        ET.SubElement(variables,'EnvironmentVariable',key='HIAIR_RUN_PHYSICAL_QA',value='1',isEnabled='YES')
        tree.write(temporary,encoding='utf-8',xml_declaration=True)
        try:
            subprocess.run(['xcodebuild','-project','HiAir.xcodeproj','-scheme',scheme,
                '-configuration','Release','-destination',destination,'-derivedDataPath',str(derived),
                '-only-testing:HiAirUITests/PhysicalActionDeliveryUITests','-allowProvisioningUpdates',
                'build-for-testing','DEVELOPMENT_TEAM=43A4KW5BKB','CODE_SIGN_STYLE=Automatic',
                'CODE_SIGN_IDENTITY=Apple Development'],cwd=IOS,check=True)
        finally:
            temporary.unlink(missing_ok=True)
    else:
        if not args.expect_sha:
            parser.error('test requires --expect-sha after immutable production deployment')
        request=urllib.request.Request('https://api.hiair.io/api/health',headers={'User-Agent':'HiAir-Physical-QA/1.0'})
        with urllib.request.urlopen(request,timeout=30,context=ssl.create_default_context(cafile=certifi.where())) as response: health=json.load(response)
        if health.get('deploy_git_sha') != args.expect_sha:
            raise SystemExit('Production SHA mismatch: physical QA not started')
        runs=sorted((derived/'Build/Products').glob('HiAirPhysicalQA_*.xctestrun'),key=lambda p:p.stat().st_mtime)
        if not runs: raise SystemExit('Build physical QA first')
        if args.result.exists(): raise SystemExit('Use a fresh result path; existing evidence preserved')
        subprocess.run(['xcodebuild','test-without-building','-xctestrun',str(runs[-1]),
            '-destination',destination,'-only-testing:HiAirUITests/PhysicalActionDeliveryUITests',
            '-resultBundlePath',str(args.result.resolve())],cwd=IOS,check=True)
        summary=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary',
            '--path',str(args.result.resolve()),'--compact'],text=True))
        if summary.get('totalTestCount') != 1 or summary.get('passedTests') != 1 or summary.get('skippedTests') != 0 or summary.get('failedTests') != 0:
            raise SystemExit('Physical QA not certified: missing/passed/skipped test counts differ')
        print('Physical ACTION live UI check: PASS (one executed, zero skipped)')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
