"""Bounded, execution-free PE import inventory for installer and extracted images."""
import hashlib
import json
from pathlib import Path
import struct
import sys

def inspect(path):
    data = Path(path).read_bytes()
    pe = struct.unpack_from('<I', data, 60)[0]
    assert data[pe:pe + 4] == b'PE\0\0'
    machine, count = struct.unpack_from('<HH', data, pe + 4)
    optional_bytes = struct.unpack_from('<H', data, pe + 20)[0]
    opt = pe + 24
    magic = struct.unpack_from('<H', data, opt)[0]
    assert magic in (0x10b, 0x20b)
    bits = 64 if magic == 0x20b else 32
    directory = opt + (112 if bits == 64 else 96)
    sections = []
    for index in range(count):
        off = opt + optional_bytes + index * 40
        vsize, rva, size, raw = struct.unpack_from('<IIII', data, off + 8)
        sections.append({'name': data[off:off + 8].rstrip(b'\0').decode('ascii', 'replace'), 'rva': rva, 'virtual_bytes': vsize, 'raw_offset': raw, 'raw_bytes': size})
    def offset(rva):
        for s in sections:
            if s['rva'] <= rva < s['rva'] + s['raw_bytes']:
                return s['raw_offset'] + rva - s['rva']
        raise ValueError(f'Unmapped RVA {rva:x}')
    def string_at(pos):
        end = data.index(b'\0', pos, min(len(data), pos + 4096))
        return data[pos:end].decode('ascii', 'replace')
    imports = []
    import_rva, import_size = struct.unpack_from('<II', data, directory + 8)
    if import_rva:
        pos = offset(import_rva)
        for _ in range(4096):
            original, stamp, chain, name, first = struct.unpack_from('<IIIII', data, pos)
            if not any((original, stamp, chain, name, first)):
                break
            names = []
            thunk = offset(original or first)
            width = bits // 8
            for index in range(65536):
                value = int.from_bytes(data[thunk + index * width:thunk + (index + 1) * width], 'little')
                if not value:
                    break
                names.append({'ordinal': value & 0xffff} if value & (1 << (bits - 1)) else string_at(offset(value) + 2))
            imports.append({'dll': string_at(offset(name)), 'symbols': names})
            pos += 20
    return {'path': str(Path(path).resolve()), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'machine': hex(machine), 'architecture': {0x14c: 'x86', 0x8664: 'x86_64', 0xaa64: 'arm64'}.get(machine, 'unknown'), 'bits': bits, 'sections': sections, 'imports': imports, 'limitations': ['Static normal import table only. Delay imports, dynamically loaded libraries and runtime behavior are not resolved.']}

if __name__ == '__main__':
    print(json.dumps([inspect(p) for p in sys.argv[1:]], indent=2))
