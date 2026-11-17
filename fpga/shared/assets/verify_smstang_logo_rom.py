#!/usr/bin/env python3
"""Verify the active SMS menu BRAM contains the intended 72x14 logo."""
from pathlib import Path
import re
HERE = Path(__file__).resolve().parent
rom = HERE.parent / "iosys" / "gowin_dpb_menu.v"
gen = (HERE / "make_smstang_logo_rom.py").read_text()
rows = re.findall(r"^    '([01]{72})',?$", gen, re.M)
assert len(rows) == 14 and all(len(r) == 72 for r in rows)
bitmap = [sum((r[x+b] == "1") << b for b in range(8)) for r in rows for x in range(0,72,8)]
bitmap += [0,0]
s = rom.read_text()
for i in range(4):
    addr = 0x1C + i
    m = re.search(r"^defparam dpb_inst_0\.INIT_RAM_%02X = 256\'h([0-9A-F]{64});" % addr, s, re.M)
    assert m, "missing logo RAM %02X" % addr
    actual = bytes.fromhex(m.group(1))[::-1]
    expected = bytes(bitmap[i*32:(i+1)*32])
    assert actual == expected, "logo RAM %02X differs from bitmap" % addr
textdisp = (HERE.parent / "iosys" / "textdisp.v").read_text()
assert "py == LOGO_Y + 14" in textdisp and "px < LOGO_X+71" in textdisp
print("PASS: active menu ROM exactly matches clean 72x14 SMSTang bitmap")
