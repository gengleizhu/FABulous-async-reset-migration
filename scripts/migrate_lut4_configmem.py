#!/usr/bin/env python3
import csv
import shutil
import sys
from pathlib import Path

if len(sys.argv) not in {2, 3}:
    raise SystemExit(
        "usage: migrate_lut4_configmem.py PROJECT [RECORD_DIRECTORY]"
    )

project = Path(sys.argv[1]).resolve()
source = project / "Tile/LUT4AB/LUT4AB_ConfigMem.csv"
record = (
    Path(sys.argv[2]).resolve()
    if len(sys.argv) == 3
    else project / "change_records/async-reset-migration"
)
backup = record / "original/Tile/LUT4AB/LUT4AB_ConfigMem.csv"
if not source.is_file():
    raise SystemExit(f"ConfigMem file not found: {source}")
backup.parent.mkdir(parents=True, exist_ok=True)
if not backup.exists():
    shutil.copy2(source, backup)


def migrate_old_index(old: int) -> int:
    # Eight 19-bit LCs become eight 20-bit LCs.
    if old < 152:
        lc, local = divmod(old, 19)
        return lc * 20 + local
    # Two InPass bits and all following switch-matrix bits move by eight.
    return old + 8


with source.open(newline="") as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    rows = list(reader)

assert fieldnames is not None
old_values = [
    int(value)
    for row in rows
    for value in row["ConfigBits_ranges"].split(";")
    if value
]
if len(old_values) == 624 and set(old_values) == set(range(624)):
    raise SystemExit("ConfigMem already appears to use a complete 624-bit mapping")
if len(old_values) != 616 or set(old_values) != set(range(616)):
    raise SystemExit(
        "expected the compatible 616-bit baseline mapping; refusing to rewrite"
    )

new_async_bits = iter(19 + 20 * lc for lc in range(8))
remaining = 8

for row in rows:
    mask = list(row["used_bits_mask"].replace("_", ""))
    values = [int(v) for v in row["ConfigBits_ranges"].split(";") if v]
    one_positions = [i for i, bit in enumerate(mask) if bit == "1"]
    assert len(one_positions) == len(values)
    assert int(row["bits_used_in_frame"]) == 32

    position_to_value = {
        pos: migrate_old_index(value)
        for pos, value in zip(one_positions, values)
    }

    # Fill previously unused physical frame positions. This preserves every old
    # physical mapping while adding one config bit per LC.
    for pos, bit in enumerate(mask):
        if remaining and bit == "0":
            mask[pos] = "1"
            position_to_value[pos] = next(new_async_bits)
            remaining -= 1

    ordered_values = [position_to_value[pos] for pos, bit in enumerate(mask) if bit == "1"]
    bits = "".join(mask)
    row["used_bits_mask"] = "_".join(bits[i:i + 4] for i in range(0, 32, 4))
    row["ConfigBits_ranges"] = ";".join(map(str, ordered_values))

assert remaining == 0
all_values = []
for row in rows:
    all_values.extend(int(v) for v in row["ConfigBits_ranges"].split(";") if v)
assert len(all_values) == 624
assert len(set(all_values)) == 624
assert set(all_values) == set(range(624))

with source.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)

print(f"updated {source}")
print("mapped config bits: 0..623 exactly once")
print("new ASYNC_SR bits:", ",".join(str(19 + 20 * lc) for lc in range(8)))
