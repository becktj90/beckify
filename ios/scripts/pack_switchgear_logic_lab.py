#!/usr/bin/env python3
"""Bundle the website's Switchgear Logic Lab unchanged; --check detects drift."""
from pathlib import Path
import argparse
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'artifacts/beckify/public/toolbox'
DEST = ROOT / 'ios/Beckify/SwitchgearLogicLabWeb'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
files = {'index.html': SOURCE / 'switchgear-logic-lab.html',
         'css/switchgear-logic-lab.css': SOURCE / 'css/switchgear-logic-lab.css',
         'js/switchgear-logic-lab-ui.js': SOURCE / 'js/switchgear-logic-lab-ui.js'}
files.update({f'js/switchgear/{p.name}': p for p in sorted((SOURCE / 'js/switchgear').glob('*.js'))})
if args.check:
    mismatches = [name for name, source in files.items()
                  if not (DEST / name).is_file() or source.read_bytes() != (DEST / name).read_bytes()]
    extras = [str(p.relative_to(DEST)) for p in DEST.rglob('*') if p.is_file() and str(p.relative_to(DEST)) not in files]
    if mismatches or extras:
        raise SystemExit('Switchgear bundle differs: ' + ', '.join(mismatches + extras))
    print(f'Switchgear bundle matches website ({len(files)} files).')
else:
    for name, source in files.items():
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    print(f'Bundled {len(files)} Switchgear Logic Lab files.')
