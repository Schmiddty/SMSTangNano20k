#!/usr/bin/env python3
"""Patch SNESTang v0.8 PicoRV32 firmware for SMSTang + GBTang core switching."""
from pathlib import Path
import re
import sys


def replace_once(text, old, new, label):
    if new in text:
        print(f"[OK] {label} already applied")
        return text
    count = text.count(old)
    if count == 1:
        print(f"[PATCH] {label}")
        return text.replace(old, new, 1)
    raise RuntimeError(f"Expected exactly one {label} target; found {count} old occurrence(s)")


def patch_firmware(path):
    text = path.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "#define CORE_NES 1\n#define CORE_SNES 2",
        "#define CORE_NES 1\n#define CORE_SNES 2\n#define CORE_GB 3\n#define CORE_SMS 5",
        "define shared core IDs (GBTang=3, SMSTang=5)",
    )

    old_welcome = '''        if (CORE_ID == 1)
            print("=== Welcome to NESTang ===");
        else
            print("~~~ Welcome to SNESTang ~~~");'''
    new_welcome = '''        if (CORE_ID == CORE_NES)
            print("=== Welcome to NESTang ===");
        else if (CORE_ID == CORE_GB)
            print("=== Welcome to GBTang ===");
        else if (CORE_ID == CORE_SMS)
            print("~~~ Welcome to SMSTang ~~~");
        else
            print("~~~ Welcome to SNESTang ~~~");'''
    text = replace_once(text, old_welcome, new_welcome, "add GBTang and SMSTang boot-menu titles")

    # The stock Select core menu scans /cores and accepts .bin, then load_core()
    # writes from address 0. This is the actual core-switch mechanism used here.
    for token in [
        'void menu_select_core(int verify)',
        'p = strcasestr(file_names[choice], ".bin")',
        'strncpy(load_fname, "/cores/", 1024)',
        'void load_core(char *fname, int verify)',
        'int addr = 0;'
    ]:
        if token not in text:
            raise RuntimeError(f"Core-switch implementation check failed; missing: {token}")
    print("[OK] existing Select core menu scans /cores/*.bin and programs from address 0")

    # Patch exact .nes-only filter in loadnes(). Exact suffix matching ensures
    # .gb is accepted without treating .gba or .gbc as .gb.
    filter_re = re.compile(
        r'(?m)^(?P<i>[ \t]*)char \*p = strcasestr\(file_names\[rom\], "\.nes"\);\s*\n'
        r'(?P=i)if \(p == NULL\) \{\s*\n'
        r'(?P=i)[ \t]*status\("Only \.nes supported"\);\s*\n'
        r'(?P=i)[ \t]*goto loadnes_end;\s*\n'
        r'(?P=i)\}'
    )
    new_filter = (
        "{i}char *p = strrchr(file_names[rom], '.');\n"
        "{i}if (p == NULL || (strcasecmp(p, \".nes\") != 0 &&\n"
        "{i}                  strcasecmp(p, \".sms\") != 0 &&\n"
        "{i}                  strcasecmp(p, \".gg\")  != 0 &&\n"
        "{i}                  strcasecmp(p, \".gb\")  != 0)) {{\n"
        "{i}    status(\"Only .nes/.sms/.gg/.gb supported\");\n"
        "{i}    goto loadnes_end;\n"
        "{i}}}"
    )
    matches = list(filter_re.finditer(text))
    if len(matches) == 1:
        m = matches[0]
        text = text[:m.start()] + new_filter.format(i=m.group('i')) + text[m.end():]
        print("[PATCH] accept exact .gb/.sms/.gg/.nes ROM extensions")
    elif len(matches) == 0 and 'strcasecmp(p, ".gb")  != 0' in text:
        print("[OK] exact raw-ROM extension filter already patched")
    else:
        raise RuntimeError(f"Expected one .nes-only loadnes() extension filter; found {len(matches)}")

    dispatch_re = re.compile(
        r'(?m)^(?P<i>[ \t]*)int res;\s*\n'
        r'(?P=i)if \(CORE_ID == 1\)\s*\n'
        r'(?P=i)[ \t]*res = loadnes\(active\);\s*\n'
        r'(?P=i)else\s*\n'
        r'(?P=i)[ \t]*res = loadsnes\(active\);'
    )
    new_dispatch = (
        "{i}int res;\n"
        "{i}char *ext = strrchr(file_names[active], '.');\n"
        "{i}if (ext && (strcasecmp(ext, \".nes\") == 0 ||\n"
        "{i}            strcasecmp(ext, \".sms\") == 0 ||\n"
        "{i}            strcasecmp(ext, \".gg\")  == 0 ||\n"
        "{i}            strcasecmp(ext, \".gb\")  == 0))\n"
        "{i}    res = loadnes(active);\n"
        "{i}else if (ext && (strcasecmp(ext, \".sfc\") == 0 ||\n"
        "{i}                 strcasecmp(ext, \".smc\") == 0))\n"
        "{i}    res = loadsnes(active);\n"
        "{i}else {{\n"
        "{i}    message(\"Unsupported ROM extension\", 1);\n"
        "{i}    break;\n"
        "{i}}}"
    )
    matches = list(dispatch_re.finditer(text))
    if len(matches) == 1:
        m = matches[0]
        text = text[:m.start()] + new_dispatch.format(i=m.group('i')) + text[m.end():]
        print("[PATCH] dispatch .gb to the raw ROM loader")
    elif len(matches) == 0 and 'strcasecmp(ext, ".gb")  == 0' in text:
        print("[OK] extension-based ROM loader dispatch already patched")
    else:
        raise RuntimeError(f"Expected one CORE_ID-based ROM loader dispatch; found {len(matches)}")

    # Scope the tail fix to loadnes() only; keep the SNES loader untouched.
    start = text.find("int loadnes(int rom) {")
    end = text.find("\nvoid backup_load", start)
    if start < 0 or end < 0:
        raise RuntimeError("Could not isolate loadnes() for tail-word safety patch")
    section = text[start:end]
    loop_re = re.compile(
        r'(?m)^(?P<i>[ \t]*)for \(int i = 0; i < br; i \+= 4\) \{\s*\n'
        r'(?P=i)[ \t]*uint32_t \*w = \(uint32_t \*\)\(load_buf \+ i\);\s*\n'
        r'(?P=i)[ \t]*snes_data\(\*w\);\s*// send actual ROM data\s*\n'
        r'(?P=i)\}'
    )
    new_loop = (
        "{i}for (int i = 0; i < br; i += 4) {{\n"
        "{i}    uint32_t w = 0;\n"
        "{i}    for (int j = 0; j < 4 && (i + j) < br; j++)\n"
        "{i}        w |= ((uint32_t)(uint8_t)load_buf[i + j]) << (8 * j);\n"
        "{i}    snes_data(w);                // send actual ROM data\n"
        "{i}}}"
    )
    matches = list(loop_re.finditer(section))
    if len(matches) == 1:
        m = matches[0]
        section = section[:m.start()] + new_loop.format(i=m.group('i')) + section[m.end():]
        print("[PATCH] zero-pad final partial ROM word")
    elif len(matches) == 0 and 'snes_data(w);                // send actual ROM data' in section:
        print("[OK] final partial ROM word already safe")
    else:
        raise RuntimeError(f"Expected one raw-ROM word loop in loadnes(); found {len(matches)}")
    text = text[:start] + section + text[end:]

    path.write_text(text, encoding="utf-8", newline="")
    check = path.read_text(encoding="utf-8")
    for token in [
        '#define CORE_GB 3',
        'print("=== Welcome to GBTang ===");',
        'strcasecmp(p, ".gb")  != 0',
        'strcasecmp(ext, ".gb")  == 0',
        'void menu_select_core(int verify)',
        'strncpy(load_fname, "/cores/", 1024)',
        'snes_data(w);                // send actual ROM data'
    ]:
        if token not in check:
            raise RuntimeError(f"Post-patch verification failed: {token}")
    if 'strcasecmp(p, ".gba")' in check or 'strcasecmp(ext, ".gba")' in check:
        raise RuntimeError("Unexpected .gba extension support found")
    print(f"[PASS] Patched and verified {path}")


def patch_sd(path):
    text = path.read_text(encoding="utf-8")
    if "uint8_t spi_receive()" not in text:
        raise RuntimeError("Expected v0.8 spi_receive(void) function not found")
    old = "response = spi_receive(0xFF);"
    new = "response = spi_receive();"
    if old in text:
        if text.count(old) != 1:
            raise RuntimeError(f"Expected one spi_receive(0xFF) call, found {text.count(old)}")
        text = text.replace(old, new, 1)
        path.write_text(text, encoding="utf-8", newline="")
        print("[PATCH] fix v0.8 SD driver spi_receive() call signature")
    elif new in text:
        print("[OK] SD driver call signature already fixed")
    else:
        raise RuntimeError("Expected spi_receive(0xFF) call not found")
    if re.search(r"\bspi_receive\s*\(\s*[^)]", text):
        raise RuntimeError("Found a remaining spi_receive() call with arguments")


def main():
    if len(sys.argv) != 3:
        print("Usage: patch_snestang_firmware.py <firmware.c> <spi_sd.c>", file=sys.stderr)
        return 2
    try:
        patch_firmware(Path(sys.argv[1]))
        patch_sd(Path(sys.argv[2]))
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
