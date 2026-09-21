#!/usr/bin/env bash
set -euo pipefail
project=/home/zyzhao/FABulous/zgl-64x64_async
record="$project/change_records/async-reset-v2-20260920"
mkdir -p "$record/validation"

echo DEPENDENCY_FILES | tee "$record/validation/source-check.log"
grep -RIlE '^module[[:space:]]+cus_mux(21|161)' "$project"/Fabric "$project"/Tile 2>/dev/null \
    | head -20 | tee -a "$record/validation/source-check.log" || true

echo BEL_MARKERS | tee -a "$record/validation/source-check.log"
grep -nE 'ASYNC_SR|NoConfigBits|async_clear|async_set|always @' \
    "$project/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
    | tee -a "$record/validation/source-check.log"

echo MAP_MARKERS | tee -a "$record/validation/source-check.log"
grep -nE 'DFF_PP[01]|DFFE_PP[01]P|LUTFF_(AR|AS|EAR|EAS)' \
    "$project/Test/yosys-0.68-maps/ff_map.v" \
    "$project/Test/yosys-0.68-maps/prims.v" \
    | tee -a "$record/validation/source-check.log"

/home/zyzhao/.fabulous/yosys-0.68/bin/yosys -ql "$record/validation/map-smoke-yosys.log" /tmp/async_reset_map_smoke.ys

echo MAPPED_CELL_TYPES | tee "$record/validation/map-smoke-summary.log"
grep -oE 'LUTFF_(ESR|ESS|EAR|EAS|SR|SS|AR|AS)' /tmp/async_reset_map_smoke.json \
    | sort | uniq -c | tee -a "$record/validation/map-smoke-summary.log"

for expected in LUTFF_ESR LUTFF_ESS LUTFF_EAR LUTFF_EAS; do
    grep -q "\"$expected\"" /tmp/async_reset_map_smoke.json
done

echo MAP_SMOKE_PASS | tee -a "$record/validation/map-smoke-summary.log"
