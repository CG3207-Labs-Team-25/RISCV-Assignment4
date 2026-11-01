import pathlib
import struct
import sys
import zlib

directory = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else (
    pathlib.Path(__file__).resolve().parents[1] / 'temp/debugger-tests')

def chunk(kind, data):
    return (struct.pack('!I', len(data)) + kind + data +
            struct.pack('!I', zlib.crc32(kind + data)))

for source in directory.glob('*.ppm'):
    tokens = source.read_text().split()
    if tokens[0] != 'P3' or tokens[3] != '255':
        raise ValueError('Expected an RGB text PPM: ' + str(source))
    width, height = map(int, tokens[1:3])
    pixels = bytes(map(int, tokens[4:]))
    if len(pixels) != width * height * 3:
        raise ValueError('Incomplete frame: ' + str(source))
    scale = 4
    rows = []
    for y in range(height):
        row = b''.join(pixels[(y*width+x)*3:(y*width+x+1)*3] * scale
                       for x in range(width))
        rows.extend([b'\0' + row] * scale)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('!2I5B', width*scale, height*scale, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    destination = source.with_suffix('.png')
    destination.write_bytes(png)
    print(destination)
