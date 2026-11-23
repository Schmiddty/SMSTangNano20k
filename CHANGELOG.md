# Changelog

## v1.1.0

- Match HDMI refresh cadence to the SMS raster: 1661 × 746 at 74.25 MHz (approximately 59.9222343 Hz).
- Hardware-tested timing adjustment eliminates tearing.
- `ce_pix`, SMS/core timing, framebuffer, menu, and controls remain unchanged.
- Existing prebuilt images are retained and were not rebuilt.

## v1.0.0

- First standalone SMSTang release for Tang Nano 20K.
- Identifies SMSTang as a port of the MiSTer SMS core.
- Credits nand2mario as the original SMSTang creator and credits the original
  menu and SD-card core-switching system.
- Includes the Fix37AJ clean blue SMSTang menu wordmark.
- Includes only SMSTang FPGA source and its prebuilt `.fs` and SD core-switch
  `.bin` images.
- Includes shared firmware retaining NESTang, SNESTang, GBTang, and SMSTang
  core selection.
- Documents BlueRetro controller compatibility, Windows/Linux builds,
  attribution, and the project roadmap.
