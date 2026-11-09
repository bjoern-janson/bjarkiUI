#!/usr/bin/env python3
"""Verify and package the castbar-only typography geometry adjustment from complete 0.2.308."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from hashlib import sha256
from subprocess import run
import re, time

work=Path('/mnt/data/bjarkiUI_work_309')
addon=work/'bjarkiUI'
tests=work/'tests'
base=Path('/mnt/data/bjarkiUI-0.2.308-hide-gcd-numbers-COMPLETE.zip')
old='0.2.308-no-gcd-countdown-test'
version='0.2.309-native-spacing-castbar'
modules=[line.strip() for line in (addon/'bjarkiUI.toc').read_text().splitlines() if line.strip().endswith('.lua')]
files=modules+['bjarkiUI.toc','bjarkiUI_Camelot.toc']
assert len(modules)==11 and len(files)==13
with ZipFile(base) as z:
    assert z.testzip() is None
    assert sorted(z.namelist())==sorted('bjarkiUI/'+name for name in files)
    for name in files:
        data=(addon/name).read_bytes()
        original=z.read('bjarkiUI/'+name)
        if name=='CastBarDigits.lua':
            assert data!=original
            assert b'local naturalAdvance=(twoWidth-dot-trailing)/3' in data
            assert b'local start=10' in data
            assert b'for i=1,#labels do' in data
            assert b'for i=1,5 do\n        local ok,b=pcall(create)' not in data
        elif name in ('bjarkiUI.lua','bjarkiUI.toc','bjarkiUI_Camelot.toc'):
            assert data==original.replace(old.encode(),version.encode()),name
        else:
            assert data==original,'unrelated module changed: '+name
for toc in ('bjarkiUI.toc','bjarkiUI_Camelot.toc'):
    lines=[x.strip() for x in (addon/toc).read_text().splitlines() if x.strip().endswith('.lua')]
    assert lines==modules
    assert version in (addon/toc).read_text()
assert version in (addon/'bjarkiUI.lua').read_text()

names=['aura-presentation.lua','castbar-digit-cells.lua','combat-icon-level-mirror.lua',
       'combat-icon-portrait-anchor.lua','frame-label-tweaks.lua','icon-skin.lua',
       'native-digit-cells.lua','pet-status-text.lua','unit-aura-retirement.lua']
counts=[];logs=[]
for name in names:
    p=run(['python',str(work/'run_lua.py'),str(tests/name),str(addon)],
          capture_output=True,text=True,timeout=120)
    assert p.returncode==0,(name,p.stdout,p.stderr)
    match=re.findall(r'(?:TOTAL:|TESTS:) (\d+) passed',p.stdout)
    assert match,name+' '+p.stdout
    counts.append(int(match[-1]))
    line=name+': '+p.stdout.splitlines()[-2].strip()
    logs.append(line)
    print(line,flush=True)
p=run(['python',str(work/'run_lua.py'),str(tests/'syntax.lua'),str(addon)],
      capture_output=True,text=True,timeout=70)
assert p.returncode==0 and 'TOTAL: 11 Lua files compile' in p.stdout,(p.stdout,p.stderr)
print('TOTAL: 11 Lua modules compile',flush=True)

out=Path('/mnt/data/bjarkiUI-0.2.309-compact-castbar-native-spacing-COMPLETE.zip')
with ZipFile(out,'w',ZIP_DEFLATED,compresslevel=9) as z:
    for name in files:z.write(addon/name,arcname='bjarkiUI/'+name)
with ZipFile(out) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(files)
    for name in files:assert z.read('bjarkiUI/'+name)==(addon/name).read_bytes()
sha=sha256(out.read_bytes()).hexdigest()
report=Path('/mnt/data/bjarkiUI-0.2.309-verification.txt')
report.write_text(f'''bjarkiUI {version} — offline verification
Date: 2026-11-09
Baseline: complete .308 (GitHub main untouched)

User report: cast-bar timer '24.0 s' is much wider than the default Blizzard
'23.7 s', with the first tens digit tucked against the bar's right edge.
User wants original visual spacing without losing stable, non-jerking digits.

Cause: CastBarDigits.lua used the largest measured numeral as the gap between
centers, and anchored its tens digit a full cell to the LEFT of Blizzard's
CastTimeText anchor, RIGHT of bar +10. It therefore shifted two-digit casts
left and spread characters too far apart.

Fix: two permanent native-bound cell layouts, 0.0-9.9 and 10.0-99.9, both
begin at the original RIGHT +10 anchor; each digit remains in a fixed cell.
The horizontal advance derives once from the rendered natural full-string
width of the original '23.7 s', subtracting the actual localized decimal
separator and suffix widths, divided by 3. This yields natural font spacing
instead of spacing for the widest glyph. The actual font, glyphs, size,
colour and shadow are copied unchanged. Existing native duration bindings
are still responsible for timing; there is no new Lua ticker/polling loop.
9 native binding cells (versus 5 before), only on the player cast bar.

Offline coverage: 1- and 2-digit cast/channel text, all tenths 0.0-99.9,
10-second handoff with mutually exclusive cells, origin matching native
CastTimeText, reduced advance, immutable anchors, combat lifecycle/fallback,
plus all other addon regression suites. Full {sum(counts):,} behavioral checks
across nine suites, 11 loaded Lua modules passed syntax checks.
ZIP integrity/TOC matched; only CastBarDigits.lua and three version strings
changed byte-for-byte against the exact .308 distribution.

Live game behavior still requires an in-game visual and combat test.
ZIP SHA256: {sha}
'''+ '\n'.join(logs)+'\n')
testzip=Path('/mnt/data/bjarkiUI-0.2.309-tests.zip')
with ZipFile(testzip,'w',ZIP_DEFLATED,compresslevel=9) as z:
    for file in sorted(tests.glob('*.lua')):z.write(file,arcname='tests/'+file.name)
    z.write(work/'run_lua.py',arcname='run_lua.py')
    z.write(work/'verify_and_package.py',arcname='verify_and_package.py')
with ZipFile(testzip) as z: assert z.testzip() is None
print('PASS addon ZIP',out,out.stat().st_size,flush=True)
print('PASS verification report',report,flush=True)
print('PASS tests ZIP',testzip,flush=True)
print('PASS behavioral total',sum(counts),flush=True)
