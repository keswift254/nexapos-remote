"""Retain the proven Win7 runner while updating its Windows version resource."""

import argparse
import hashlib
from pathlib import Path
import struct


def patch(path: Path, old: str, new: str, old_build: int, new_build: int) -> None:
    data = bytearray(path.read_bytes())
    old_text = f"{old}+{old_build}".encode("utf-16le")
    new_text = f"{new}+{new_build}".encode("utf-16le")
    if len(old_text) != len(new_text) or data.count(old_text) != 2 or data.count(new_text):
        raise ValueError("Unexpected Win7 runner version strings")
    data = data.replace(old_text, new_text)

    signature = bytes.fromhex("bd04effe")  # VS_FIXEDFILEINFO
    offset = data.find(signature)
    if offset < 0 or data.find(signature, offset + 1) >= 0:
        raise ValueError("Expected exactly one Windows fixed version resource")
    old_parts = [int(part) for part in old.split(".")]
    new_parts = [int(part) for part in new.split(".")]
    if len(old_parts) != 3 or len(new_parts) != 3:
        raise ValueError("Expected three-part release versions")
    expected_old = ((old_parts[0] << 16) | old_parts[1], (old_parts[2] << 16) | old_build)
    expected_new = ((new_parts[0] << 16) | new_parts[1], (new_parts[2] << 16) | new_build)
    for ms_offset, ls_offset in ((8, 12), (16, 20)):
        if struct.unpack_from("<II", data, offset + ms_offset) != expected_old:
            raise ValueError("Unexpected Windows fixed file/product version")
        struct.pack_into("<II", data, offset + ms_offset, *expected_new)
    path.write_bytes(data)
    print(f"Patched Win7 runner to {new}+{new_build}: {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("runner", type=Path)
    parser.add_argument("--old", default="1.0.52")
    parser.add_argument("--new", required=True)
    parser.add_argument("--old-build", type=int, default=53)
    parser.add_argument("--new-build", type=int, required=True)
    args = parser.parse_args()
    patch(args.runner, args.old, args.new, args.old_build, args.new_build)
