#!/usr/bin/env python3
"""Build/run the live ACTION UI check on a physical iPhone, without debug mocks."""
import argparse
import json
import plistlib
import subprocess
import tempfile
import uuid
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / 'mobile/ios'


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('mode', choices=['build','test'])
    parser.add_argument('--device', required=True)
    parser.add_argument('--suite', choices=['action','runtime','restore'], default='action')
    parser.add_argument('--derived-data', type=Path, default=ROOT/'.evidence/action-device-derived')
    parser.add_argument('--expect-sha')
    parser.add_argument('--readback-run')
    parser.add_argument('--result', type=Path, default=ROOT/'.evidence/action-physical-tests.xcresult')
    args=parser.parse_args()
    derived=args.derived_data.resolve()
    destination=f'platform=iOS,id={args.device}'
    test_class={'action':'PhysicalActionDeliveryUITests',
        'runtime':'PhysicalRuntimePerformanceUITests', 'restore':'PhysicalRestoreDeliveryUITests'}[args.suite]
    if args.mode=='build':
        if subprocess.check_output(['git','status','--porcelain','--','mobile/ios'],cwd=ROOT,text=True).strip():
            raise SystemExit('Commit mobile source before building physical QA')
        source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        mobile_tree=subprocess.check_output(['git','rev-parse','HEAD:mobile/ios'],cwd=ROOT,text=True).strip()
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
                f'-only-testing:HiAirUITests/{test_class}','-allowProvisioningUpdates',
                'build-for-testing','DEVELOPMENT_TEAM=43A4KW5BKB','CODE_SIGN_STYLE=Automatic',
                'CODE_SIGN_IDENTITY=Apple Development'],cwd=IOS,check=True)
        finally:
            temporary.unlink(missing_ok=True)
        if subprocess.check_output(['git','status','--porcelain','--','mobile/ios'],cwd=ROOT,text=True).strip():
            raise SystemExit('Mobile source changed while building physical QA')
        current_tree=subprocess.check_output(['git','rev-parse','HEAD:mobile/ios'],cwd=ROOT,text=True).strip()
        if current_tree != mobile_tree:
            raise SystemExit('Mobile source commit changed while building physical QA')
        (derived/'physical-source.json').write_text(json.dumps({'source_sha':source,
            'ios_tree':mobile_tree, 'scheme':scheme, 'configuration':'Release'},indent=2)+'\n')
    else:
        if not args.expect_sha:
            parser.error('test requires --expect-sha after immutable production deployment')
        import sys
        sys.path.insert(0,str(ROOT/'scripts/release'))
        from check_mobile_release_source import source_digest, fetch_health
        health=fetch_health(args.readback_run)
        if health.get('status')!='ok' or health.get('service')!='hiair-backend':
            raise SystemExit('Production health invalid: physical QA not started')
        if health.get('deploy_git_sha') != args.expect_sha:
            raise SystemExit('Production SHA mismatch: physical QA not started')
        if health.get('app_source_sha256') != source_digest(args.expect_sha):
            raise SystemExit('Running app fingerprint mismatch: physical QA not started')
        provenance=json.loads((derived/'physical-source.json').read_text())
        tree=subprocess.check_output(['git','rev-parse','HEAD:mobile/ios'],cwd=ROOT,text=True).strip()
        if provenance['ios_tree']!=tree:
            raise SystemExit('Physical test binary is stale; rebuild from current source')
        runs=list((derived/'Build/Products').glob(provenance['scheme']+'*.xctestrun'))
        if not runs: raise SystemExit('Build physical QA first')
        if args.result.exists(): raise SystemExit('Use a fresh result path; existing evidence preserved')
        # Bundle-ID-only XCUIApplication launches the already installed app; XCTest
        # does not guarantee replacement of the host. Install this proven candidate
        # explicitly, preserving its data container, and read back its version.
        app=derived/'Build/Products/Release-iphoneos/HiAir.app'
        with (app/'Info.plist').open('rb') as stream:
            info=plistlib.load(stream)
        subprocess.run(['xcrun','devicectl','device','install','app','--device',args.device,
            str(app)],check=True,capture_output=True,text=True)
        with tempfile.TemporaryDirectory(prefix='hiair-device-version-') as directory:
            output=Path(directory)/'apps.json'
            subprocess.run(['xcrun','devicectl','device','info','apps','--device',args.device,
                '--json-output',str(output)],check=True,capture_output=True,text=True)
            installed=next((item for item in json.loads(output.read_text())['result']['apps']
                if item.get('bundleIdentifier')==info['CFBundleIdentifier']),None)
        if not installed or installed.get('bundleVersion')!=str(info['CFBundleVersion']) or installed.get('version')!=info['CFBundleShortVersionString']:
            raise SystemExit('Installed candidate version mismatch: physical QA not started')
        print(f"Installed physical candidate {installed['version']} ({installed['bundleVersion']})",flush=True)
        subprocess.run(['xcodebuild','test-without-building','-xctestrun',str(runs[-1]),
            '-destination',destination,f'-only-testing:HiAirUITests/{test_class}',
            '-resultBundlePath',str(args.result.resolve())],cwd=IOS,check=True)
        summary=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary',
            '--path',str(args.result.resolve()),'--compact'],text=True))
        if summary.get('totalTestCount') != 1 or summary.get('passedTests') != 1 or summary.get('skippedTests') != 0 or summary.get('failedTests') != 0:
            raise SystemExit('Physical QA not certified: missing/passed/skipped test counts differ')
        print(f'Physical {args.suite} live UI check: PASS (one executed, zero skipped)')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
