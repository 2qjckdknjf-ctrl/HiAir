#!/usr/bin/env python3
"""Read-only public health/source and privileged aggregate latency probe."""
import json
import os
import re
import time
import urllib.request
from pathlib import Path

expected=os.environ.get('EXPECTED_SHA','')
if not re.fullmatch('[0-9a-f]{40}',expected):
    raise SystemExit('A full expected API commit is required')
result={}
try:
    for label,url in [('api','https://api.hiair.io/api/health'),('web','https://hiair.io/release.json')]:
        start=time.monotonic()
        request=urllib.request.Request(url,headers={'User-Agent':'HiAir-Readback/1.0'})
        with urllib.request.urlopen(request,timeout=15) as response: payload=json.load(response)
        result[label]={'duration_ms':round((time.monotonic()-start)*1000),'source_sha':payload.get('deploy_git_sha') or payload.get('source_sha')}
        if label=='api':
            if payload.get('status')!='ok' or payload.get('service')!='hiair-backend':
                raise ValueError('API health is invalid')
            result[label].update(status=payload['status'],service=payload['service'])
            from pathlib import Path
            import sys
            sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'release'))
            from check_mobile_release_source import source_digest
            if payload.get('app_source_sha256')!=source_digest(expected):
                raise ValueError('API application code fingerprint differs from the expected source')
            result[label]['app_source_sha256']=payload['app_source_sha256']
    if result['api']['source_sha']!=expected: raise ValueError('API source mismatch')
    token=os.environ.get('NOTIFICATION_ADMIN_TOKEN','')
    if token:
        request=urllib.request.Request('https://api.hiair.io/api/observability/metrics',
            headers={'X-Admin-Token':token,'User-Agent':'HiAir-Readback/1.0'})
        with urllib.request.urlopen(request,timeout=15) as response: metrics=json.load(response)
        result['metrics']={key:metrics.get(key) for key in ('total_requests','total_errors','avg_latency_ms','by_path_latency')}
    print(json.dumps(result,indent=2))
finally:
    Path('runtime-readback.json').write_text(json.dumps(result,indent=2)+'\n')
