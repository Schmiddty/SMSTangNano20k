SMSTang shared PicoRV32 IOSys firmware
======================================

This is the shared firmware for the Tang Nano 20K core-switching menu. It
preserves nand2mario's original Select core menu and SD:/cores/*.bin loader.

Supported core IDs:
  NESTang  = 1
  SNESTang = 2
  GBTang   = 3
  SMSTang  = 5

The release bundles only the SMSTang FPGA core. Compatible NESTang, SNESTang,
and GBTang core-switch .bin images must be supplied separately in SD:/cores/.

Example:
  SD:/cores/smstang_nano20k.bin  (included)
  SD:/cores/nestang.bin          (user supplied)
  SD:/cores/snestang.bin         (user supplied)
  SD:/cores/gbtang.bin           (user supplied)

Choose Select core in the menu, select the desired .bin image, and reboot
when prompted. A core-switch .bin is not the same as a Gowin .fs flash image.

The shared firmware ROM paths include .nes, .sms, .gg, .gb, .sfc, and .smc;
the selected core determines which ROM formats it can use.

BlueRetro adapters have been tested with the shared controller setup. See
RELEASE_NOTES.md for compatibility notes and the Tang Nano 20K community
reference link. Verify the adapter's output mode and wiring before connecting.

The supplied prebuilt firmware image is release-assets/firmware_smstang.bin.
Flash it at SPI flash address 0x500000. Flash the FPGA .fs at 0x000000.
Do not erase the entire SPI flash.

To rebuild on Windows, run BUILD_SMSTANG_GBTANG_FIRMWARE.bat.
Linux build instructions are in RELEASE_NOTES.md.
