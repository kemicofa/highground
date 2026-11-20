"""Embed bundled uncompressed TGA art in browser previews, using stdlib."""
import base64
from pathlib import Path
import struct
import zlib


def crest_data():
    source = Path(__file__).resolve().parents[1] / 'libs/HighgroundKit/media/HighgroundCrest.tga'
    return tga_data(source)


def tga_data(source):
    data = source.read_bytes()
    width, height, bits, flags = struct.unpack_from('<HHBB', data, 12)
    if data[1] != 0 or data[2] != 2 or bits not in (24, 32):
        raise ValueError('Preview art must be an uncompressed RGB/RGBA TGA')
    stride = bits // 8
    pixels = data[18 + data[0]:]
    rows = []
    for y in range(height):
        index = y if flags & 32 else height - y - 1
        row = pixels[index * width * stride:(index + 1) * width * stride]
        rgb = bytearray()
        for x in range(0, len(row), stride):
            rgb.extend((row[x + 2], row[x + 1], row[x]))
            if stride == 4:
                rgb.append(row[x + 3])
        rows.append(b'\0' + rgb)

    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))

    header = struct.pack('>IIBBBBB', width, height, 8, 6 if stride == 4 else 2, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    return 'data:image/png;base64,' + base64.b64encode(png).decode()
