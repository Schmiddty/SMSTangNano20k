# SMSTang v1.0.0

## Project background

SMSTang is a port of the **SMS-MiSTer core** to the Sipeed Tang Nano 20K.
The original SMSTang project was created by **nand2mario (NAND2Mario)**.
This release continues to use nand2mario's original menu system, shared
PicoRV32 IOSys firmware foundation, and SD-card core-switching mechanism.

The release package contains only SMSTang FPGA source and SMSTang FPGA images.
The shared firmware remains multi-core and retains compatibility with
NESTang, SNESTang, and GBTang core images supplied separately by the user.

## Ready-to-use release contents

- `release-assets/firmware_smstang.bin` — shared firmware; flash at `0x500000`.
- `release-assets/smstang_nano20k.fs` — Tang Nano 20K FPGA image; flash at `0x000000`.
- `SD_CARD/cores/smstang_nano20k.bin` — SMSTang core-switch image; copy to
  the SD card's `/cores/` directory.

The three binary assets above are included byte-for-byte as provided. Their
SHA-256 hashes are listed in `SHA256SUMS.txt`.

## Quick installation

1. Flash `release-assets/firmware_smstang.bin` at SPI flash address `0x500000`.
2. Flash `release-assets/smstang_nano20k.fs` at SPI flash address `0x000000`,
   or keep the existing FPGA image if you do not want to update it.
3. Copy `SD_CARD/cores/smstang_nano20k.bin` to the SD card's `/cores/` directory.
4. Put SMS ROMs on the SD card and use the SMSTang menu to load them.

Do not erase the entire SPI flash when updating either image.

## Shared firmware and core switching

The supplied firmware is the shared PicoRV32 IOSys firmware based on the
nand2mario menu/core-switching implementation. Its **Select core** menu scans
`/cores/*.bin` and programs the selected core image from SPI flash address `0`.

The firmware retains these core IDs:

| Core | Core ID | User-supplied SD image |
|---|---:|---|
| NESTang | 1 | `/cores/nestang.bin` |
| SNESTang | 2 | `/cores/snestang.bin` |
| GBTang | 3 | `/cores/gbtang.bin` |
| SMSTang | 5 | `/cores/smstang_nano20k.bin` (included) |

To use NESTang, SNESTang, or GBTang, obtain a compatible Tang Nano 20K
core-switch `.bin` image for that core, copy it into `/cores/`, choose it
through **Select core**, and reboot when prompted. The release does not
bundle the other cores' FPGA source or bitstreams. A Gowin `.fs` image is for
direct FPGA flashing; it is not a substitute for the `.bin` core-switch image.

The firmware's ROM handling includes `.nes`, `.sms`, `.gg`, `.gb`, `.sfc`, and
`.smc` paths. The selected core determines which formats are meaningful.

## BlueRetro controller compatibility

The SMSTang release uses the shared IOSys/controller input path from the
NESTang/SNESTang family. BlueRetro adapters have been tested with this
controller setup. Use a compatible BlueRetro adapter/output configuration
and the corresponding Tang Nano 20K controller wiring. BlueRetro hardware
variants and output modes may have different pinouts; verify the adapter's
configuration and wiring before connecting it.

Reference discussion:
https://github.com/nand2mario/nestang/issues/67

That GitHub issue is a community discussion/reference, not an official
BlueRetro wiring specification. Confirm the exact pin mapping for the
adapter and configuration being used.

## Build from source

### Windows

- FPGA: run `fpga/build_windows.bat` with Gowin EDA and Python 3 installed.
- Firmware: run `firmware/BUILD_SMSTANG_GBTANG_FIRMWARE.bat`. The script
  downloads the SNESTang v0.8 source used as the shared IOSys firmware base
  and the xPack RISC-V compiler if needed, applies the release patch, and
  builds `firmware/output/firmware_sms_gbtang.bin`.

### Linux

These instructions build from source on a Linux host. Building is optional
when using the supplied prebuilt release images.

#### Requirements

- Gowin EDA Linux edition for Tang Nano 20K, including its `gw_sh` Tcl console.
- Python 3.
- `curl` and `unzip`.
- A RISC-V bare-metal toolchain providing `riscv-none-elf-gcc` and
  `riscv-none-elf-objcopy`.

#### Build the FPGA images

From the repository root:

```sh
cd fpga
GOWIN_GW_SH=/path/to/Gowin/IDE/bin/gw_sh python3 build_sms_core.py --all
```

Replace the path with the actual Linux `gw_sh` path. The script generates
`fpga/build/build.tcl`, runs Gowin, and checks for fresh `.fs` and `.bin`
outputs. The `.fs` is the SPI-flash FPGA image; the `.bin` is the core-switch
image for `SD:/cores/`.

#### Build the shared firmware

Install the required host tools (Debian/Ubuntu example):

```sh
sudo apt-get update
sudo apt-get install -y python3 curl unzip
```

Install a RISC-V bare-metal toolchain from your distribution or xPack. Ensure
both commands are on `PATH`:

```sh
riscv-none-elf-gcc --version
riscv-none-elf-objcopy --version
```

Then download and extract the SNESTang v0.8 source used by the shared firmware
builder:

```sh
mkdir -p firmware/work
cd firmware
curl -L \
  https://github.com/nand2mario/snestang/archive/refs/tags/v0.8.zip \
  -o work/snestang-v0.8.zip
unzip -q -o work/snestang-v0.8.zip -d work
```

The extracted directory is normally `work/snestang-0.8`. Apply the supplied
patcher:

```sh
python3 patch_snestang_firmware.py \
  work/snestang-0.8/firmware/firmware.c \
  work/snestang-0.8/firmware/spi_sd.c
```

Build using the same freestanding RV32I options as the Windows builder:

```sh
cd work/snestang-0.8/firmware
CFLAGS="-Wall -O2 -g -mabi=ilp32 -march=rv32i -ffreestanding"

riscv-none-elf-gcc $CFLAGS -c start.S -o start.o
riscv-none-elf-gcc $CFLAGS -c firmware.c -o firmware.o
riscv-none-elf-gcc $CFLAGS -c picorv32.c -o picorv32.o
riscv-none-elf-gcc $CFLAGS -c spi_sd.c -o spi_sd.o
riscv-none-elf-gcc $CFLAGS -c spiflash.c -o spiflash.o
riscv-none-elf-gcc $CFLAGS -c fatfs/diskio.c -o fatfs/diskio.o
riscv-none-elf-gcc $CFLAGS -c fatfs/ff.c -o fatfs/ff.o
riscv-none-elf-gcc $CFLAGS -c fatfs/ffunicode.c -o fatfs/ffunicode.o

riscv-none-elf-gcc -mabi=ilp32 -march=rv32i \
  -Wl,--build-id=none,-Bstatic,-T,baremetal.ld \
  -nostdlib start.o firmware.o picorv32.o spi_sd.o spiflash.o \
  fatfs/diskio.o fatfs/ff.o fatfs/ffunicode.o -lgcc -o firmware.elf

riscv-none-elf-objcopy firmware.elf firmware.bin -O binary
mkdir -p ../../../output
cp firmware.bin ../../../output/firmware_sms_gbtang.bin
```

Check that `firmware.bin` is no larger than 262144 bytes. Flash firmware at
`0x500000`. Do not erase the entire SPI flash.

### SD-card core layout

The release includes `/cores/smstang_nano20k.bin`. To enable switching to
other systems, place compatible core-switch images in the same directory:

```text
/cores/smstang_nano20k.bin
/cores/nestang.bin
/cores/snestang.bin
/cores/gbtang.bin
```

Only the SMSTang image is included in this release. NESTang, SNESTang, and
GBTang images must be obtained separately.

## Credits and licensing

- **nand2mario (NAND2Mario)** — original SMSTang project; original menu,
  PicoRV32 IOSys menu firmware foundation, and core-switching implementation.
- **MiSTer-devel SMS_MiSTer contributors** — upstream Sega Master System /
  Game Gear core from which SMSTang is ported.
- **Ben** — original Papilio Sega Master System implementation on which the
  MiSTer SMS core is based.
- **Daniel Wallner** — T80 Z80 core.
- **Sorgelig** — T80 updates and additional inherited FPGA RTL contributions.
- **Jose Tejada (jt) / Jotego** — jt89 PSG implementation.
- **Sameer Puri** — HDMI/TMDS modules.
- **Katsumi Degawa** — DualShock controller RTL.
- **Alastair M. Robinson** — audio/PWM RTL components.
- **Claire Xenia Wolf** — PicoRV32 and simpleuart.
- **Gowin Semiconductor** — Gowin-generated/support RTL where identified by
  source headers.
- Additional authors and contributors are credited in the copyright and
  license headers retained in individual source files.

See `THIRD_PARTY_NOTICES.md`, `LICENSE`, and individual source headers for
complete applicable license terms. Upstream copyright/license notices are
retained.

## Roadmap

- Fix any outstanding bugs.
- Port SMSTang to the MiSTle framework.

## Verification status

The supplied firmware `.bin`, FPGA `.fs`, and SD core `.bin` are included
unchanged and were SHA-256 checked against the supplied attachments. ZIP
integrity and release-layout checks were performed. The supplied prebuilt
images were not rebuilt during this packaging step. Do not infer fresh
synthesis or hardware validation from the packaging checks.
