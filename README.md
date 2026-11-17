
# SMSTang Nano 20k v1.0.0

SMSTang is a Sega Master System / Game Gear FPGA core for the **Sipeed Tang Nano 20K** (GW2AR-18C). It is a port of the **SMS-MiSTer core** to the Tang Nano 20K platform.

This release continues the work of the original SMSTang and NANO-BLAST projects, together with the upstream MiSTer core and the shared Tang Nano firmware ecosystem.

## Installation

1. Flash `release-assets/firmware_smstang.bin` at SPI flash address `0x500000`.
2. Flash `release-assets/smstang_nano20k.fs` at SPI flash address `0x000000`, or keep the existing FPGA image if you do not want to update it.
3. Copy `SD_CARD/cores/smstang_nano20k.bin` to the SD card's `/cores/` directory.
4. Put SMS ROMs on the SD card and use the SMSTang menu to load them.

**Never erase the entire SPI flash** when updating either image.

## Shared firmware and core switching

The included firmware retains the original **Select core** menu and scans `SD:/cores/*.bin`. It can select compatible core images for the following systems:

| Core | Firmware core ID | SD-card image |
|---|---:|---|
| NESTang | 1 | `nestang.bin` |
| SNESTang | 2 | `snestang.bin` |
| GBTang | 3 | `gbtang.bin` |
| SMSTang | 5 | `smstang_nano20k.bin` (included) |

Only the SMSTang FPGA source and SMSTang `.fs`/`.bin` images are bundled. Users who want to switch to another system must obtain a compatible Tang Nano 20K core-switch `.bin` image separately and place it in `/cores/`. Select the image using **Select core** and reboot when prompted. Core-switch images are not the same as Gowin `.fs` images used for direct FPGA flashing.

The shared firmware supports ROM paths for `.nes`, `.sms`, `.gg`, `.gb`, `.sfc`, and `.smc`. The selected core determines which formats are meaningful.

## BlueRetro controller compatibility

This release uses the shared IOSys/controller input path used by the NESTang/SNESTang family. **BlueRetro adapters have been tested with this controller setup**. Connect the adapter using the compatible controller interface and wiring for the Tang Nano 20K; do not assume that every BlueRetro hardware variant or output mode uses the same pinout.

A community discussion/reference for BlueRetro use with the Tang Nano 20K is available at:

https://github.com/nand2mario/nestang/issues/67

The issue is a discussion reference, not a formal BlueRetro wiring specification. Check your adapter's configured output mode and pinout before connecting it.

## Build from source

### Windows

Install Gowin EDA for Tang Nano 20K and Python 3, then:

- **FPGA:** run `fpga/build_windows.bat`. The script generates the Gowin Tcl project and invokes `gw_sh.exe`. The default executable path is the standard Gowin V1.9.11.03 Windows installation; set `GOWIN_GW_SH` to override it.
- **Shared firmware:** run `firmware/BUILD_SMSTANG_GBTANG_FIRMWARE.bat`. The script downloads the SNESTang v0.8 firmware source and xPack RISC-V compiler when needed, applies the SMSTang patch, and builds `firmware/output/firmware_sms_gbtang.bin`.

### Linux

For the FPGA build, install Gowin EDA for Linux (including `gw_sh`) and Python 3, then run from the repository root:

```sh
cd fpga
GOWIN_GW_SH=/path/to/Gowin/IDE/bin/gw_sh python3 build_sms_core.py --all
```

For the shared firmware build, install `curl`, `unzip`, Python 3, and a RISC-V bare-metal toolchain providing `riscv-none-elf-gcc` and `riscv-none-elf-objcopy`. The Windows builder and the firmware patcher in `firmware/` provide the source and patch details.

## Source layout

- `fpga/` — SMSTang FPGA source, Gowin project-generation script, constraints, and menu logo assets.
- `firmware/` — shared SMSTang/NESTang/SNESTang/GBTang firmware builder and patcher.
- `release-assets/` — supplied prebuilt firmware and FPGA flash images.
- `SD_CARD/` — supplied SMSTang core image in its expected SD-card location.
- `LICENSE` and `THIRD_PARTY_NOTICES.md` — licensing and attribution.

## Roadmap

- Fix any outstanding bugs.
- Port SMSTang to the MiSTle framework.

## Credits and acknowledgements

SMSTang is a derivative project built on the work of many developers and open-source projects. This release would not exist without their contributions.

### Main project lineage

- **NANO-BLAST project authors** — original SMSTang Tang Nano 20K port and integration work. This release continues and modifies that work.
- **nand2mario (NAND2Mario)** — creator of the original SMSTang project. Original menu system, PicoRV32 IOSys firmware foundation, and SD-card core-switching implementation.
  https://github.com/nand2mario/smstang
- **MiSTer-devel SMS_MiSTer contributors** — upstream Sega Master System / Game Gear core from which SMSTang is ported.
  https://github.com/MiSTer-devel/SMS_MiSTer
- **Ben** — original Papilio Sega Master System implementation, identified by the SMS_MiSTer project as an earlier basis for its core.
  http://fpga-hacks.blogspot.de/

### FPGA and RTL contributors

- **Daniel Wallner** — original T80 Z80 CPU core.
- **Sorgelig** — T80 updates and other inherited RTL contributions.
- **Jose Tejada (jt / Jotego)** — jt89 PSG implementation.
- **Sameer Puri** — HDMI/TMDS implementation components.
  https://github.com/sameer
- **Katsumi Degawa** — DualShock controller RTL.
- **Alastair M. Robinson** — audio/PWM RTL components.
- **Claire Xenia Wolf** — PicoRV32 and simpleuart.
- **Gowin Semiconductor Corporation** — Gowin support and generated RTL components where identified by source headers.

### Shared firmware and related projects

- **nand2mario and the SNESTang project contributors** — SNESTang v0.8 firmware source used as the shared firmware foundation, with SMSTang-specific modifications.
  https://github.com/nand2mario/snestang
- **Sergiy Dvodnenko (srg320) and gyurco** — creators of SNES_FPGA, acknowledged by the SNESTang project as the basis for its SNES core.
- **NESTang and SNESTang contributors** — contributions to the shared Tang Nano firmware, controller, menu, and core-switching ecosystem.

Additional original authors and contributors are identified in the copyright and license headers retained in the individual source files.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md), `LICENSE`, and individual source headers for further attribution and applicable license terms. This summary does not replace those notices.

## AI disclosure

Development of this port was assisted by **ChatGPT, using the free version**.

No money was paid to any AI-related entity in connection with the making of this port.

AI assistance does not alter original authorship, credits, copyright notices, or licenses.

## Validation

The supplied binary files were copied without modification and checked by SHA-256. The release ZIP was checked for integrity. The prebuilt images were not rebuilt during packaging; board-level operation should be tested on a Tang Nano 20K before claiming hardware validation.
