#!/usr/bin/env bash
set -euo pipefail

PROJECT=/home/zyzhao/FABulous/zgl-64x64_async
RECORD="$PROJECT/change_records/async-reset-v2-20260920"
export PATH=/home/zyzhao/.fabulous/oss-cad-suite/bin:/nix/store/9ysyys63a84rasqkdzdsjjha1fyr9ads-FABulous-env/bin:/home/zyzhao/miniforge3/envs/fabulous/bin:/usr/bin:/bin

mkdir -p "$RECORD/validation"
command -v iverilog
command -v vvp

iverilog -g2012 -s async_reset_bel_tb \
  -o "$RECORD/validation/async_reset_bel_tb.vvp" \
  "$PROJECT/Fabric/models_pack.v" \
  "$PROJECT/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  /tmp/async_reset_bel_tb.v

vvp "$RECORD/validation/async_reset_bel_tb.vvp" \
  | tee "$RECORD/validation/async-reset-priority-sim.log"

grep -q '^PASS:' "$RECORD/validation/async-reset-priority-sim.log"
