"""Windows Gowin build for the SMSTang Tang Nano 20K FPGA core."""
from pathlib import Path
import os,subprocess,sys,json,hashlib,re,html,shutil
P=Path(__file__).resolve().parent;O=P/'build';O.mkdir(exist_ok=True)
sources=[P/'opll.v',*sorted((P/'engine').rglob('*.v')),*sorted((P/'engine').rglob('*.sv')),*sorted((P/'rtl').glob('*.v')),*sorted((P/'rtl').glob('*.sv')),*[p for p in sorted((P/'shared').rglob('*.v')) if p.name not in {'mcu_uart.v','textdisp.v'} or (p.parent.name=='iosys' and p.name=='textdisp.v')],*[p for p in sorted((P/'shared').rglob('*.sv'))]]
shutil.copy2(P/'mboot.hex', O/'mboot.hex')
sdc=O/'smstang.sdc';sdc.write_text('''create_clock -name sys_clk -period 37.037037 [get_ports {sys_clk}]
create_clock -name main -period 15.432099 [get_nets {clk}]
create_clock -name hclk5 -period 2.693603 [get_nets {hclk5}]
create_generated_clock -name hclk -source [get_nets {hclk5}] -master_clock hclk5 -divide_by 5 [get_nets {hclk}]
set_clock_groups -asynchronous -group [get_clocks {main}] -group [get_clocks {hclk hclk5}]
''')
def tp(path): return Path(path).resolve().as_posix()
lines=[f'create_project -force -name smstang -dir {{{tp(O / "project")}}} -pn GW2AR-LV18QN88C8/I7 -device_version C',f'cd {{{tp(O)}}}','set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7']
lines += [f'add_file -type verilog {{{tp(p)}}}' for p in sources]
lines += [f'add_file -type cst {{{tp(P / "constraints/board.cst")}}}',f'add_file -type sdc {{{tp(sdc)}}}','set_option -synthesis_tool gowinsynthesis','set_option -top_module sms_nano_top','set_option -verilog_std sysv2017','set_option -output_base_name smstang','set_option -rw_check_on_ram 1','set_option -place_option 2','set_option -route_option 1']
lines += [f'set_option -use_{x}_as_gpio 1' for x in ['mspi','sspi','ready','done','i2c','cpu']]
lines += ['set_option -multi_boot 1','set_option -bit_compress 1','run '+('all' if '--all' in sys.argv else 'syn')]
(O/'build-input-sha256.json').write_text(json.dumps({str(p.relative_to(P)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources+[P/'constraints/board.cst',P/'mboot.hex',sdc]},indent=2)+'\n');tcl=O/'build.tcl';tcl.write_text('\n'.join(lines)+'\n')
gw_sh=Path(os.environ.get("GOWIN_GW_SH", r"C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe"))
for old_ext in ('.fs', '.bin'):
    for old_image in O.rglob('*' + old_ext):
        try: old_image.unlink()
        except OSError: pass
if not gw_sh.is_file(): sys.exit(f"Gowin Tcl executable not found: {gw_sh}")
with (O/'gowin-build.log').open('w',encoding='utf-8') as log:
    r=subprocess.run([str(gw_sh),str(tcl)],cwd=O,stdout=log,stderr=subprocess.STDOUT,text=True)
log_text=(O/'gowin-build.log').read_text(encoding='utf-8',errors='replace')
fs=list(O.rglob('*.fs'))
bins=list(O.rglob('*.bin'))
if r.returncode!=0 or 'ERROR ' in log_text or not fs:
    sys.exit(f"Gowin build failed or produced no .fs bitstream. Inspect {O/'gowin-build.log'}")
if not bins:
    sys.exit(f"No fresh .bin core-switch image was produced. Do not reuse an older .bin. Inspect {O/'gowin-build.log'} and Gowin output settings.")
print('Gowin build produced .fs:', *[str(p) for p in fs], sep='\n')
if bins:
    print('Optional .bin output:', *[str(p) for p in bins], sep='\n')
