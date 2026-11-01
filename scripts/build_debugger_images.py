import argparse
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--rars', type=pathlib.Path, default=ROOT / 'temp/tools/rars.jar')
parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'temp/debugger-images')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
command = ['java', '-Djava.awt.headless=true',
           '-Djava.util.prefs.userRoot=' + str(ROOT / 'temp/tools/java-prefs'),
           '-jar', str(args.rars), 'nc', 'a', 'ae1']
for segment, name in [('.text', 'Debugger_IROM.mem'), ('.data', 'Debugger_DMEM.mem')]:
    command += ['dump', segment, 'HexText', str(args.output / name)]
command += ['dump', '.text', 'SegmentWindow', str(args.output / 'listing.txt'),
            str(ROOT / 'asm_src/Pipeline_Debugger.asm')]
subprocess.run(command, check=True)
for name, depth, fill in [('Debugger_IROM.mem', 512, '00000013'),
                          ('Debugger_DMEM.mem', 128, '00000000')]:
    path = args.output / name
    words = path.read_text().splitlines()
    if len(words) > depth:
        if name != 'Debugger_DMEM.mem' or any(int(word, 16) for word in words[depth:]):
            raise SystemExit(name + ' exceeds available memory')
        words = words[:depth]
    words += [fill] * (depth - len(words))
    text = '\n'.join(word.lower() for word in words) + '\n'
    path.write_text(text)
    if args.check and text != (ROOT / 'asm_mem' / name).read_text():
        raise SystemExit(name + ' does not match assembly')
print('Debugger images assembled' + (' and verified' if args.check else ''))
