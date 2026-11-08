"""Repeat static installer checks. Does not launch or install the Windows target."""
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parent
TARGET = Path('/Users/a.tsoulfas/Desktop/StremioSetup-v5.0.27_arm64.exe')
data = TARGET.read_bytes()
record = json.loads((ROOT / 'evidence/installer-pe-resources.json').read_text())
if 'normalized_result' not in record:
    raise ValueError('Expected a complete REA evidence record')
assert hashlib.sha256(data).hexdigest() == record['normalized_result']['artifact']['sha256']

def align4(n):
    return (n + 3) & ~3

def version_node(raw, start=0):
    length, value_length, kind = struct.unpack_from('<HHH', raw, start)
    if length < 6 or start + length > len(raw):
        raise ValueError('Invalid version node')
    pos = start + 6
    end = pos
    while raw[end:end + 2] != b'\0\0':
        end += 2
        if end >= start + length:
            raise ValueError('Missing version key terminator')
    key = raw[pos:end].decode('utf-16le')
    pos = align4(end + 2)
    value_bytes = value_length * 2 if kind == 1 else value_length
    value = raw[pos:pos + value_bytes]
    node = {'key': key, 'value': value.decode('utf-16le').strip('\0 ').strip() if kind == 1 else value.hex(), 'children': []}
    pos = align4(pos + value_bytes)
    while pos + 6 <= start + length:
        child_length = struct.unpack_from('<H', raw, pos)[0]
        if not child_length:
            break
        node['children'].append(version_node(raw, pos))
        pos = align4(pos + child_length)
    return node

version_resource = next(r for r in record['normalized_result']['resources'] if r['type'] == {'kind': 'id', 'id': 16})
location = version_resource['payload']['location']
version_bytes = data[location['offset']:location['offset'] + location['bytes']]
assert hashlib.sha256(version_bytes).hexdigest() == version_resource['payload']['sha256']
pe_offset = struct.unpack_from('<I', data, 0x3c)[0]
machine = struct.unpack_from('<H', data, pe_offset + 4)[0]
optional_header = pe_offset + 24
assert struct.unpack_from('<H', data, optional_header)[0] == 0x10b
cert_offset, cert_size = struct.unpack_from('<II', data, optional_header + 96 + 4 * 8)
probe = subprocess.run(['innoextract', '--list', str(TARGET)], capture_output=True, text=True)
summary = {
    'path': str(TARGET), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
    'rea_evidence_id': record['evidence_id'], 'machine': hex(machine), 'format': 'PE32',
    'certificate_table': {'offset': cert_offset, 'bytes': cert_size, 'signature_verified': False},
    'version_resource': version_node(version_bytes),
    'inno_markers': [{'offset': m.start(), 'text': m.group().decode('ascii')} for m in re.finditer(rb'Inno Setup Setup Data \([^\x00]{1,30}\)', data)],
    'extraction_probe': {'command': ['innoextract', '--list', str(TARGET)], 'exit_code': probe.returncode, 'stdout': probe.stdout, 'stderr': probe.stderr},
    'limitations': ['Installer bootstrap only; payload architecture and dependency versions are unverified.', 'Embedded certificate presence is not signature validation.', 'Version strings are metadata, not publisher authentication.'],
}
(ROOT / 'evidence/installer-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
manifest = [{'path': str(p.relative_to(ROOT)), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted((ROOT / 'sources').rglob('*')) if p.is_file()]
(ROOT / 'evidence/source-file-digests.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'sha256': summary['sha256'], 'version': summary['version_resource'], 'certificate_table': summary['certificate_table'], 'source_files': len(manifest), 'extraction_exit_code': probe.returncode}, indent=2))
