# Third-party notices and credits

SMSTang is a derivative work. Copyright and license notices in the inherited
source files are part of the source and must be retained. This summary is
provided for attribution convenience; it does not replace individual source
headers or license texts.

## Main project lineage

- **NANO-BLAST project authors** — original SMSTang Tang Nano 20K port and
  integration work. This release continues and modifies that work.
- **nand2mario (NAND2Mario)** — creator of the original SMSTang project.
  This release also uses nand2mario's original menu system, PicoRV32 IOSys
  menu firmware foundation, and SD-card core-switching mechanism.
  https://github.com/nand2mario/smstang
- **MiSTer-devel SMS_MiSTer contributors** — upstream Sega Master System /
  Game Gear core ported by SMSTang.
  https://github.com/MiSTer-devel/SMS_MiSTer
- **Ben** — original Papilio Sega Master System implementation, identified
  by the SMS_MiSTer project as the basis for its core.
  http://fpga-hacks.blogspot.de/

## Identifiable bundled RTL contributors

- **Daniel Wallner** — T80 Z80 CPU core.
- **Sorgelig** — T80 updates and other inherited RTL contributions, as
  identified in source headers.
- **Jose Tejada Gomez (jt / Jotego)** — jt89 PSG implementation.
- **Sameer Puri** — HDMI/TMDS implementation components.
  https://github.com/sameer
- **Katsumi Degawa** — DualShock controller RTL.
- **Alastair M. Robinson** — audio/PWM RTL components.
- **Claire Xenia Wolf** — PicoRV32 and simpleuart.
- **Gowin Semiconductor Corporation** — Gowin support/generated RTL where
  identified by source headers.

Other original authors are credited in the corresponding source-file
headers. Those headers and their associated license terms are retained.

## Firmware dependencies

The shared firmware builder downloads SNESTang v0.8 source from
https://github.com/nand2mario/snestang and applies the release's firmware
patch. The upstream copyright and license notices remain in the downloaded
source and are not replaced by this project's notices.

PicoRV32 retains its upstream license header in
`fpga/shared/iosys/picorv32.v`.

## License compliance

Consult `LICENSE` and each inherited source file's header for the applicable
license. This summary is not a substitute for reproducing the full license
texts required by those licenses.
