"""Install Quaternius packs that the user downloaded by hand from itch.io.

    python -I tools/install_quaternius.py "<path>/Universal Base Characters[Standard].zip" [...more zips]

Licence: the pack pages say CC0, but quaternius.com/license (QAL v1.0) forbids
redistributing the assets themselves as assets. The repository is public, so the
files go to assets/third_party/quaternius/ (git-ignored) and are never committed.
Only model/texture/text files are extracted; nothing is executed.
"""
import sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/third_party/quaternius'
KEEP = ('.gltf', '.glb', '.bin', '.png', '.jpg', '.jpeg', '.txt', '.md')

if len(sys.argv) < 2:
    sys.exit(__doc__)
for arg in sys.argv[1:]:
    zip_path = Path(arg)
    slug = zip_path.stem.split('[')[0].strip().lower().replace(' - ', '-').replace(' ', '-')
    out = DEST / slug
    kept = 0
    with zipfile.ZipFile(zip_path) as z:
        for info in z.infolist():
            rel = Path(info.filename)
            if info.is_dir() or rel.suffix.lower() not in KEEP or '..' in rel.parts or rel.is_absolute():
                continue
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(info))
            kept += 1
    (out / 'SOURCE.txt').write_text('%s\nLicence: see quaternius.com/license and the itch.io page.\n' % zip_path.name, encoding='utf-8')
    print(slug, kept, 'files ->', out)
