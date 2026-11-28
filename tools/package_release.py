#!/usr/bin/env python3
"""Build the fork's BPS ZIP from the two builds and upstream's release patches."""

import argparse
import re
import struct
import zipfile
from pathlib import Path
from zlib import crc32


def encode_number(number):
    result = bytearray()
    while number >= 128:
        result.append(number & 127)
        number = (number >> 7) - 1
    result.append(number | 128)
    return result


class PatchReader:
    def __init__(self, data):
        self.data = memoryview(data)
        self.position = 4
        self.end = len(data) - 12
        if self.end < self.position or data[:4] != b"BPS1":
            raise ValueError("Invalid BPS header")
        self.source_crc, self.target_crc, patch_crc = struct.unpack("<III", data[-12:])
        if crc32(self.data[:-4]) != patch_crc:
            raise ValueError("Invalid upstream BPS checksum")

    def read(self, size):
        start = self.position
        self.position += size
        if self.position > self.end:
            raise ValueError("Truncated BPS command or metadata")
        return self.data[start:self.position]

    def number(self):
        result, shift = 0, 1
        while True:
            byte = self.read(1)[0]
            result += (byte & 127) * shift
            if byte & 128:
                return result
            shift <<= 7
            result += shift

    def offset(self):
        number = self.number()
        return -(number >> 1) if number & 1 else number >> 1


def retarget(upstream_patch, stock, caught):
    """Keep upstream's valid source/copy references while changing the target."""
    reader = PatchReader(upstream_patch)
    source_size = reader.number()
    target_size = reader.number()
    metadata = reader.read(reader.number())
    if len(stock) != target_size or crc32(stock) != reader.target_crc:
        raise ValueError("Tagged upstream build does not match the published BPS target")

    patch = bytearray(b"BPS1")
    patch.extend(encode_number(source_size))
    patch.extend(encode_number(len(caught)))
    patch.extend(encode_number(len(metadata)))
    patch.extend(metadata)

    old_source_offset = old_target_offset = 0
    new_source_offset = new_target_offset = 0
    output = 0
    literal_start = None
    while reader.position < reader.end:
        command = reader.number()
        mode, size = command & 3, (command >> 2) + 1
        end = output + size
        if end > target_size:
            raise ValueError("BPS command extends past the target")

        if mode == 0:
            if end > source_size:
                raise ValueError("BPS SourceRead extends past the source")
            reference = output
        elif mode == 1:
            if reader.read(size) != stock[output:end]:
                raise ValueError("Upstream BPS literal differs from the tagged build")
        elif mode == 2:
            reference = old_source_offset + reader.offset()
            old_source_offset = reference + size
            if reference < 0 or old_source_offset > source_size:
                raise ValueError("BPS SourceCopy extends past the source")
        else:
            reference = old_target_offset + reader.offset()
            old_target_offset = reference + size
            if not 0 <= reference < output or stock[reference:old_target_offset] != stock[output:end]:
                raise ValueError("Invalid upstream BPS TargetCopy")

        count = min(end, len(caught)) - output
        if count > 0:
            target_bytes = caught[output:output + count]
            if mode == 3:
                reusable = target_bytes == caught[reference:reference + count]
            else:
                reusable = mode != 1 and target_bytes == stock[output:output + count]

            if reusable:
                if literal_start is not None:
                    patch.extend(encode_number(((output - literal_start - 1) << 2) | 1))
                    patch.extend(caught[literal_start:output])
                    literal_start = None
                patch.extend(encode_number(((count - 1) << 2) | mode))
                if mode in (2, 3):
                    previous = new_source_offset if mode == 2 else new_target_offset
                    delta = reference - previous
                    patch.extend(encode_number((abs(delta) << 1) | (delta < 0)))
                    if mode == 2:
                        new_source_offset = reference + count
                    else:
                        new_target_offset = reference + count
            elif literal_start is None:
                literal_start = output
        output = end

    if output != target_size:
        raise ValueError("Upstream BPS does not fill the target")
    if literal_start is None and output < len(caught):
        literal_start = output
    if literal_start is not None:
        patch.extend(encode_number(((len(caught) - literal_start - 1) << 2) | 1))
        patch.extend(caught[literal_start:])

    patch.extend(struct.pack("<II", reader.source_crc, crc32(caught)))
    patch.extend(struct.pack("<I", crc32(patch)))
    return patch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("upstream_assets", type=Path)
    parser.add_argument("stock_build", type=Path)
    parser.add_argument("caught_build", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", args.tag):
        parser.error(f"Unexpected release tag {args.tag!r}")

    version = args.tag[1:].replace(".", "_")
    patches = {}
    for color in ("Blue", "Green", "Red"):
        rom = f"poke{color.lower()}.gbc"
        upstream_name = f"Pokemon_Pure{color}_{args.tag}.bps"
        try:
            patches[f"Pokemon_Pure{color} {version}CI.bps"] = retarget(
                (args.upstream_assets / upstream_name).read_bytes(),
                (args.stock_build / rom).read_bytes(),
                (args.caught_build / rom).read_bytes(),
            )
        except ValueError as error:
            parser.exit(1, f"{upstream_name}: {error}\n")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    destination = args.output_dir / f"Caught_indicator_{version}.zip"
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, patch in patches.items():
            archive.writestr(name, patch)
    print(destination)


if __name__ == "__main__":
    main()
