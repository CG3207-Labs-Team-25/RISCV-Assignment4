import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'temp' / 'debugger-tests'
OUT.mkdir(parents=True, exist_ok=True)
local = ROOT / 'temp/tools/iverilog/usr'
compiler = shutil.which('iverilog') or str(local / 'bin/iverilog')
runtime = shutil.which('vvp') or str(local / 'bin/vvp')
sources = sorted((ROOT / 'RISCV-CPU.srcs/sources_1/new').glob('*.v'))
sources += [ROOT / 'RISCV-CPU.srcs/sources_1/imports/verilog/MCycle.v']
sources += sorted((ROOT / 'RISCV-CPU.srcs/sim_1').rglob('*.v'))
tops = sys.argv[1:] or [
    'test_BranchPrediction', 'test_Wrapper_Prediction', 'test_Wrapper_BF',
    'test_Wrapper_assigned', 'test_Wrapper_Demo', 'test_Wrapper_LoadStore', 'test_MCycle',
]
os.chdir(ROOT / 'asm_mem')
for top in tops:
    command = [compiler]
    if not shutil.which('iverilog'):
        command += ['-B', '../temp/tools/iverilog/usr/lib/x86_64-linux-gnu/ivl']
    executable = OUT / (top + '.vvp')
    command += ['-g2012', '-s', top, '-o', str(executable)] + list(map(str, sources))
    subprocess.run(command, check=True)
    result = subprocess.run([runtime, str(executable)], text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120)
    (OUT / (top + '.log')).write_text(result.stdout)
    print(top + ': ' + '\n'.join(line for line in result.stdout.splitlines()
                               if 'ALL ' in line or 'FAIL' in line or 'FATAL' in line))
    if result.returncode or 'FAIL' in result.stdout or 'FATAL' in result.stdout:
        print(result.stdout)
        sys.exit(1)
