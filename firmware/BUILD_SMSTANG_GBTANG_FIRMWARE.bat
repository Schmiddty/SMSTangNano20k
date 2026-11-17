@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "ROOT=%CD%"
set "WORK=%ROOT%work"
set "ZIP=%WORK%\snestang-v0.8.zip"
set "URL=https://github.com/nand2mario/snestang/archive/refs/tags/v0.8.zip"
set "TOOLBIN="
if exist "%ROOT%\output\firmware_sms_gbtang.bin" del /q "%ROOT%\output\firmware_sms_gbtang.bin"

if not exist "%WORK%" mkdir "%WORK%"
if not exist "%ZIP%" (
  echo Downloading official SNESTang v0.8 source...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%ZIP%'"
  if errorlevel 1 (echo ERROR: failed to download SNESTang v0.8 source.& exit /b 1)
)
if not exist "%WORK%\snestang-0.8\firmware\firmware.c" (
  echo Extracting source...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force -LiteralPath '%ZIP%' -DestinationPath '%WORK%'"
  if errorlevel 1 (echo ERROR: failed to extract source archive.& exit /b 1)
)
set "FW=%WORK%\snestang-0.8\firmware"
if not exist "%FW%\firmware.c" (
  echo ERROR: firmware.c was not found in SNESTang v0.8 source.
  exit /b 1
)

python "%ROOT%\patch_snestang_firmware.py" "%FW%\firmware.c" "%FW%\spi_sd.c"
if errorlevel 1 exit /b 1

rem Find a compiler already installed on this PC.
for /f "delims=" %%G in ('where riscv-none-elf-gcc.exe 2^>nul') do if not defined TOOLBIN set "TOOLBIN=%%~dpG"

rem If absent, download the same portable xPack Windows compiler used by the prior SMS firmware build.
if not defined TOOLBIN (
  set "TOOLROOT=%ROOT%\tools"
  set "TOOLZIP=%ROOT%\tools\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip"
  set "TOOLURL=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v15.2.0-1/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip"
  if not exist "!TOOLROOT!" mkdir "!TOOLROOT!"
  if not defined TOOLBIN (
    if not exist "!TOOLZIP!" (
      echo.
      echo No RISC-V compiler found. Downloading official xPack Windows compiler - one-time download, about 300 MB...
      powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '!TOOLURL!' -OutFile '!TOOLZIP!'"
      if errorlevel 1 (echo ERROR: xPack compiler download failed. Check internet access and rerun.& exit /b 2)
    )
    echo Extracting RISC-V compiler...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Force -LiteralPath '!TOOLZIP!' -DestinationPath '!TOOLROOT!'"
    if errorlevel 1 (echo ERROR: failed to extract xPack compiler.& exit /b 2)
    set "TOOLBIN=!TOOLROOT!\xpack-riscv-none-elf-gcc-15.2.0-1\bin"
  )
)
if not defined TOOLBIN (echo ERROR: RISC-V compiler not found after setup.& exit /b 2)
if not exist "%TOOLBIN%\riscv-none-elf-objcopy.exe" (echo ERROR: riscv-none-elf-objcopy.exe missing beside compiler.& exit /b 2)

cd /d "%FW%"
set "CFLAGS=-Wall -O2 -g -mabi=ilp32 -march=rv32i -ffreestanding"
echo.
echo Building SMSTang + GBTang shared PicoRV32 firmware...
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c start.S -o start.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c firmware.c -o firmware.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c picorv32.c -o picorv32.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c spi_sd.c -o spi_sd.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c spiflash.c -o spiflash.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c fatfs\diskio.c -o fatfs\diskio.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c fatfs\ff.c -o fatfs\ff.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" %CFLAGS% -c fatfs\ffunicode.c -o fatfs\ffunicode.o || goto build_fail
"%TOOLBIN%\riscv-none-elf-gcc.exe" -mabi=ilp32 -march=rv32i -Wl,--build-id=none,-Bstatic,-T,baremetal.ld -nostdlib start.o firmware.o picorv32.o spi_sd.o spiflash.o fatfs\diskio.o fatfs\ff.o fatfs\ffunicode.o -lgcc -o firmware.elf || goto build_fail
"%TOOLBIN%\riscv-none-elf-objcopy.exe" firmware.elf firmware.bin -O binary || goto build_fail
for %%I in (firmware.bin) do set "SIZE=%%~zI"
if !SIZE! GTR 262144 goto firmware_too_large
if not exist "%ROOT%\output" mkdir "%ROOT%\output"
copy /y firmware.bin "%ROOT%\output\firmware_sms_gbtang.bin" >nul || goto build_fail
certutil -hashfile "%ROOT%\output\firmware_sms_gbtang.bin" SHA256

echo.
echo BUILD SUCCESS: "%ROOT%\output\firmware_sms_gbtang.bin" (!SIZE! bytes)
echo Flash this PicoRV32 firmware at SPI flash address 0x500000.
echo Put the existing GBTang bitstream at /cores/gbtang.bin on the SD card.
echo In the menu choose Select core, select gbtang.bin, then reboot.
echo The GBTang menu should then accept .gb ROM files.
echo Do NOT erase the whole flash. Leave the FPGA image at address 0 untouched.
exit /b 0

:firmware_too_large
echo ERROR: firmware.bin exceeds the 262144-byte firmware slot limit.
goto build_fail

:build_fail
echo BUILD FAILED. Do not flash an old or partial output file.
exit /b 1
