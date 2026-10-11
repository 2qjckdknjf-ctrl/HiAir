"""Content identity of deployed Python application code, independent of environment labels."""
import hashlib
from functools import lru_cache
from pathlib import Path


def hash_sources(sources):
    digest = hashlib.sha256()
    for name, content in sorted(sources):
        digest.update(name.encode('utf-8') + b'\0')
        digest.update(len(content).to_bytes(8, 'big'))
        digest.update(content)
    return digest.hexdigest()


@lru_cache(maxsize=1)
def application_source_digest():
    root = Path(__file__).resolve().parents[1]
    return hash_sources((p.relative_to(root).as_posix(), p.read_bytes())
                        for p in root.rglob('*.py') if '__pycache__' not in p.parts)
