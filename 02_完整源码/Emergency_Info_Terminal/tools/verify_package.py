"""Verify the SHA-256 inventory of the source package."""
from pathlib import Path
import hashlib,json,sys

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'verification/package_sha256.json').read_text(encoding='utf-8'))
failed=[]
for relative,expected in manifest.items():
    path=root/relative
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:
        failed.append(relative)
if failed:
    print('FAIL\n'+'\n'.join(failed))
    sys.exit(1)
print(f'PASS: {len(manifest)} files verified')
