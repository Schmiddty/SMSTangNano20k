#!/usr/bin/env python3
"""Regenerate the clean 72x14 1-bpp SMSTang menu wordmark ROM.

The bitmap is intentionally fixed-size to match IOSys textdisp.v's logo fetch
contract (14 rows x 9 bytes). No image/font packages are needed to regenerate
Gowin DPB initialization data.
"""
from pathlib import Path
import re

ROWS = (
    '000111111000011100000111000011111001111111111000000000000000000000000000',
    '001111111000111100001111001111111101111111111000000000000000000000000000',
    '011100001000111110011111001110001000001111000000000000000000000000000000',
    '011100000000111110011111001100000000001110001111110000111111100011111111',
    '011111100000111110111111001111100000001110001101111001111111100111111110',
    '001111110000110111110110001111111000001110000000111001110011100111001110',
    '000011111001110111101110000011111000001100001111111001110011100110001110',
    '000000111001110011001110000000111000011100011100111001110011101110001110',
    '110000111001110011001110010000111000011100111000110001100011101111011110',
    '111111110001110000001110011111110000011100011111110011100011100111111100',
    '011111100001100000001100011111100000011100011110110011100011000011101100',
    '000000000000000000000000000000000000000000000000000000000000000000011100',
    '000000000000000000000000000000000000000000000000000000000000001111111000',
    '000000000000000000000000000000000000000000000000000000000000000111110000',
)
assert len(ROWS) == 14 and all(len(row) == 72 for row in ROWS)

# IOSys stores each row as nine little-bit-order bytes; the DPB parameter
# literals are emitted as 32-byte big-endian hexadecimal words.
bitmap = [sum((row[x + bit] == '1') << bit for bit in range(8))
          for row in ROWS for x in range(0, 72, 8)]
bitmap.extend([0, 0])
lines = []
for i in range(4):
    data = bytes(bitmap[i * 32:(i + 1) * 32][::-1]).hex().upper()
    lines.append(
        "defparam dpb_inst_0.INIT_RAM_%02X = 256'h%s; // SMSTang clean italic wordmark, 72x14 1bpp"
        % (0x1C + i, data)
    )
path = Path(__file__).resolve().parents[1] / 'iosys' / 'gowin_dpb_menu.v'
s = path.read_text()
for i, line in enumerate(lines):
    addr = '%02X' % (0x1C + i)
    s, count = re.subn(r'^defparam dpb_inst_0\.INIT_RAM_' + addr + r' = .*', line, s, flags=re.M)
    assert count == 1, (addr, count)
path.write_text(s)
print('Updated', path)
