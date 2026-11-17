# GitHub publishing checklist

Suggested repository: `SMSTang`
Suggested tag: `v1.0.0`
Suggested title: `SMSTang v1.0.0`

1. Upload the contents of this source/release ZIP to the public repository.
2. Review `THIRD_PARTY_NOTICES.md` and retained per-file license notices.
3. Attach `release-assets/firmware_smstang.bin`, `release-assets/smstang_nano20k.fs`,
   and `SD_CARD/cores/smstang_nano20k.bin` (also included in the ZIP).
4. Publish `RELEASE_NOTES.md` as the GitHub release description.
5. Attach `SHA256SUMS.txt` and verify uploaded assets against it.
6. Test the included firmware and FPGA images on a Tang Nano 20K before claiming
   hardware validation.

The shared firmware retains GBTang core switching. The repository itself
contains only the SMSTang FPGA core; a GBTang core image must be supplied by
the user in `/cores/gbtang.bin`.
