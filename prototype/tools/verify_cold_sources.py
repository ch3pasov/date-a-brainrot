"""Compare read-only Studio source fingerprints with the saved prototype."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json

parser = argparse.ArgumentParser()
parser.add_argument('version', type=int)
parser.add_argument('--series', choices=('day', 'night'), default='day')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
evidence = root / 'prototype/evidence'
records = json.loads((evidence / f'{args.series}-cold-source-records-v{args.version}.json').read_text())
records = list(records.values()) if isinstance(records, dict) else records
by_name = {item['name']: item for item in records}
sources = sorted((root / 'src').rglob('*.luau'))
assert len(by_name) == len(records) == len(sources), 'Source count or names differ'
hashes = {}
for source in sources:
    data = source.read_bytes()
    name = source.name.replace('.client', '').replace('.server', '').removesuffix('.luau')
    fingerprint = 5381
    for byte in data:
        fingerprint = (fingerprint * 33 + byte) & 0xffffffff
    assert by_name[name]['bytes'] == len(data) and by_name[name]['djb2'] == fingerprint, name
    hashes[str(source.relative_to(root))] = hashlib.sha256(data).hexdigest()
result = {
    'checked_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'cold_open_verified': True,
    'source_fingerprints_match': True,
    'source_sha256': hashes,
    'scripts': len(sources),
    'built_binary_sha256': hashlib.sha256((root / 'build/DateABrainrot-Prototype.rbxl').read_bytes()).hexdigest(),
}
(evidence / f'{args.series}-cold-verification-v{args.version}.json').write_text(json.dumps(result, indent=2) + '\n')
print(f'Cold-open sources match: {len(sources)}/{len(sources)}')
