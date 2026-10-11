"""Real temporary Git graphs verify mobile/API source reconciliation."""
import importlib.util
import subprocess
from pathlib import Path
import pytest

spec=importlib.util.spec_from_file_location('mobile_guard',Path(__file__).resolve().parents[2]/'scripts/release/check_mobile_release_source.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)


def test_mobile_guard_allows_docs_but_rejects_diverged_api_and_feature_source(tmp_path):
    def git(*args):
        return subprocess.check_output(['git',*args],cwd=tmp_path,text=True).strip()
    git('init','-q','-b','main')
    git('config','user.name','Test');git('config','user.email','test@example.invalid')
    (tmp_path/'backend').mkdir();(tmp_path/'backend/app.py').write_text('first')
    (tmp_path/'mobile/ios').mkdir(parents=True);(tmp_path/'mobile/ios/source.swift').write_text('first')
    git('add','.');git('commit','-qm','baseline');baseline=git('rev-parse','HEAD')
    (tmp_path/'note.md').write_text('docs');git('add','.');git('commit','-qm','docs');docs=git('rev-parse','HEAD')
    git('update-ref','refs/remotes/origin/main',docs)
    assert module.validate_source(docs,baseline,tmp_path)['api_sha']==baseline
    module.validate_artifact_checkout(baseline,docs,'mobile/ios',tmp_path)
    git('switch','-qc','feature')
    (tmp_path/'backend/app.py').write_text('changed');git('add','.');git('commit','-qm','feature');feature=git('rev-parse','HEAD')
    with pytest.raises(ValueError,match='reachable'):
        module.validate_source(feature,baseline,tmp_path)
    git('update-ref','refs/remotes/origin/main',feature)
    with pytest.raises(ValueError,match='differs'):
        module.validate_source(feature,baseline,tmp_path)
    assert module.validate_source(feature,feature,tmp_path)['source_sha']==feature
    (tmp_path/'mobile/ios/source.swift').write_text('changed');git('add','.');git('commit','-qm','mobile')
    mobile=git('rev-parse','HEAD')
    with pytest.raises(ValueError,match='mobile source differs'):
        module.validate_artifact_checkout(feature,mobile,'mobile/ios',tmp_path)
    with pytest.raises(ValueError,match='immutable'):
        module.validate_source(feature,'not-a-sha',tmp_path)


def test_manifest_rejects_stale_or_changed_binary(tmp_path):
    import hashlib,json
    artifact=tmp_path/'build.ipa';artifact.write_bytes(b'verified artifact')
    source='a'*40;manifest=tmp_path/'manifest.json'
    manifest.write_text(json.dumps({'ios_source_sha':source,'artifacts':[
        {'path':str(artifact),'sha256':hashlib.sha256(artifact.read_bytes()).hexdigest()}]}))
    assert module.source_from_manifest(artifact,manifest,tmp_path)==source
    artifact.write_bytes(b'changed artifact')
    with pytest.raises(ValueError,match='hash'):
        module.source_from_manifest(artifact,manifest,tmp_path)
    with pytest.raises(ValueError,match='absent'):
        module.source_from_manifest(tmp_path/'different.ipa',manifest,tmp_path)
