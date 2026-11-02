#!/usr/bin/env bash
set -euo pipefail

# Disassemble a raw SPARC NAND image in blocks.
# Preserve original file offsets and skip erased blocks.

IMAGE="${1:-mtd0.img}"
OUTPUT="${2:-mtd0-disassembly.disasm}"
BLOCK_SIZE=4096
OBJDUMP="sparc64-linux-gnu-objdump"

if [[ ! -f "$IMAGE" ]]; then
    echo "Image not found: $IMAGE" >&2
    exit 1
fi

if ! command -v "$OBJDUMP" >/dev/null 2>&1; then
    echo "Install binutils-sparc64-linux-gnu first." >&2
    exit 1
fi

if [[ "$IMAGE" == "$OUTPUT" ]]; then
    echo "Input and output must be different files." >&2
    exit 1
fi

python3 - "$IMAGE" "$OUTPUT" "$BLOCK_SIZE" "$OBJDUMP" <<'PY'
import os
import sys
import subprocess

image, output, block_size, objdump = sys.argv[1:]
block_size = int(block_size)
size = os.path.getsize(image)
processed = 0
skipped = 0

with open(image, "rb") as source, \
     open(output, "w", encoding="utf-8") as result:

    result.write("SPARC NAND FLASH DISASSEMBLY\n")
    result.write(f"Image: {image}\n")
    result.write(f"Size: {size} bytes\n")
    result.write(f"Block size: {block_size} bytes\n\n")

    for start in range(0, size, block_size):
        end = min(start + block_size, size)
        source.seek(start)
        data = source.read(end - start)

        if all(byte == 0xFF for byte in data):
            skipped += 1
            continue

        print(f"Disassembling 0x{start:08X} - 0x{end:08X}")

        result.write("\n" + "=" * 72 + "\n")
        result.write(f"BLOCK 0x{start:08X} - 0x{end:08X}\n")
        result.write("=" * 72 + "\n\n")

        command = [
            objdump,
            "-D",
            "-b", "binary",
            "-m", "sparc",
            "-EB",
            "--adjust-vma=0",
            f"--start-address={start}",
            f"--stop-address={end}",
            image
        ]

        completed = subprocess.run(
            command,
            stdout=result,
            stderr=subprocess.PIPE,
            text=True
        )

        if completed.returncode != 0:
            sys.exit(
                f"objdump failed at 0x{start:X}: "
                f"{completed.stderr}"
            )

        processed += 1

print(f"\nCompleted: {output}")
print(f"Disassembled blocks: {processed}")
print(f"Skipped erased blocks: {skipped}")
PY
