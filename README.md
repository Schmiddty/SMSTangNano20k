# SMSTang v1.0.0

SMSTang is a Sega Master System / Game Gear FPGA core for the **Sipeed Tang
Nano 20K** (GW2AR-18C). It is a port of the **SMS-MiSTer core** to the Tang
Nano 20K platform.

The original SMSTang project was created by **nand2mario (NAND2Mario)**.
This release also uses nand2mario's original menu system, PicoRV32 IOSys
firmware architecture, and SD-card core-switching mechanism.

This repository/release bundles only the SMSTang FPGA core. The shared
firmware can also select compatible NESTang, SNESTang, and GBTang core images
when users provide those images themselves.

## Ready-to-use files

- `release-assets/firmware_smstang.bin` — shared firmware; flash at `0x500000`.
- `release-assets/smstang_nano20k.fs` — FPGA image; flash at `0x000000`.
- `SD_CARD/cores/smstang_nano20k.bin` — copy to SD card `/cores/`.

These three files are included byte-for-byte from the release attachments.
See `RELEASE_NOTES.md` for installation and Windows/Linux build instructions.

## Shared firmware and core switching

The included firmware retains nand2mario's **Select core** menu and scans
`SD:/cores/*.bin`. It can select compatible core images for the following
systems:

| Core | Firmware core ID | SD-card image |
|---|---:|---|
| NESTang | 1 | `nestang.bin` |
| SNESTang | 2 | `snestang.bin` |
| GBTang | 3 | `gbtang.bin` |
| SMSTang | 5 | `smstang_nano20k.bin` (included) |

Only the SMSTang FPGA source and SMSTang `.fs`/`.bin` images are bundled.
Users who want to switch to another system must obtain a compatible Tang Nano
20K core-switch `.bin` image separately and place it in `/cores/`. Select the
image using **Select core** and reboot when prompted. Core-switch images are
not the same as Gowin `.fs` images used for direct FPGA flashing.

The firmware's ROM handling includes `.nes`, `.sms`, `.gg`, `.gb`, `.sfc`, and
`.smc` paths. Availability of a ROM extension depends on the selected core.

## BlueRetro controller compatibility

This release uses the shared IOSys/controller input path used by the
NESTang/SNESTang family. **BlueRetro adapters have been tested with this
controller setup**. Connect the adapter using the compatible controller
interface and wiring for the Tang Nano 20K; do not assume that every
BlueRetro hardware variant or output mode uses the same pinout.

A community discussion/reference for BlueRetro use with the Tang Nano 20K is
available at
https://github.com/nand2mario/nestang/issues/67

The issue is a discussion reference, not a formal BlueRetro wiring
specification. Check your adapter's configured output mode and pinout before
connecting it.

## Source layout

- `fpga/` — SMSTang FPGA source, Gowin project-generation script, constraints,
  and menu logo assets.
- `firmware/` — shared SMSTang/NESTang/SNESTang/GBTang firmware builder and
  patcher.
- `release-assets/` — supplied prebuilt firmware and FPGA flash images.
- `SD_CARD/` — supplied SMSTang core image in its expected SD-card location.
- `LICENSE` and `THIRD_PARTY_NOTICES.md` — licensing and attribution.

## Flash locations

- FPGA `.fs`: `0x000000`
- Shared PicoRV32 IOSys firmware: `0x500000`

Never erase the entire SPI flash when updating either image.

## Roadmap

- Fix any outstanding bugs.
- Port SMSTang to the MiSTle framework.

## Validation

The supplied binary files were copied without modification and checked by
SHA-256. The release ZIP was checked for integrity. The prebuilt images were
not rebuilt during packaging; board-level operation should be tested on a
Tang Nano 20K before claiming hardware validation.
