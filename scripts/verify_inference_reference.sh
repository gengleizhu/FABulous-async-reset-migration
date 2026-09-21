#!/usr/bin/env bash
set -euo pipefail
project=/home/zyzhao/FABulous/zgl-64x64_async
record="$project/change_records/async-reset-v2-20260920/validation"

/home/zyzhao/.fabulous/yosys-0.68/bin/yosys -ql "$record/bel-inference-yosys.log" /tmp/async_bel_inference.ys

python3 - <<'PY' | tee "$record/cell-type-summary.log"
import json
from collections import Counter

def cell_types(path, module):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return Counter(cell["type"] for cell in data["modules"][module]["cells"].values())

mapped = cell_types("/tmp/async_reset_map_smoke.json", "async_reset_map_smoke")
bel = cell_types("/tmp/async_bel_inference.json", "LUT4c_frame_config_dffesr")
print("USER_MAPPING_TOP_CELL_TYPES")
for name, count in sorted(mapped.items()):
    print(count, name)
print("BEL_INFERENCE_TOP_CELL_TYPES")
for name, count in sorted(bel.items()):
    print(count, name)

expected = {"LUTFF_ESR", "LUTFF_ESS", "LUTFF_EAR", "LUTFF_EAS"}
missing = expected.difference(mapped)
if missing:
    raise SystemExit(f"missing mapped cells: {sorted(missing)}")
if not any(name in bel for name in ("$dffsre", "$dffsr", "$adff", "$aldff")):
    raise SystemExit("BEL did not infer an asynchronous sequential cell")
print("INFERENCE_PASS")
PY
