#!/usr/bin/env bash
set -euo pipefail
PROJECT=/home/zyzhao/FABulous/zgl-64x64_async
RECORD="$PROJECT/change_records/async-reset-v2-20260920"
export PATH=/home/zyzhao/miniforge3/envs/fabulous/bin:/usr/bin:/bin
unset LD_LIBRARY_PATH PYTHONPATH PYTHONHOME
cd "$PROJECT/Test"
/home/zyzhao/.fabulous/yosys-0.68/bin/yosys \
  -ql "$RECORD/validation/async-nextpnr-wrapper-yosys.log" \
  /tmp/async_nextpnr_wrapper.ys

task run-nextpnr \
  DESIGN=async_nextpnr_wrapper \
  JSON_FILE=/tmp/async_nextpnr_wrapper.json \
  FASM_FILE="$RECORD/validation/async_nextpnr_wrapper.fasm" \
  NEXTPNR_PATH=/nix/store/rwc7bibpqi9hprxkjynfd9c5vjflxkij-nextpnr-unstable/bin/nextpnr-generic \
  LOG_FILE="$RECORD/validation/async-reset-nextpnr.log" \
  'NEXTPNR_EXTRA_ARGS=--freq 10 --placer heap --router router2 --seed 1 --threads 4 --placer-heap-beta 0.65' \
  > "$RECORD/validation/async-reset-nextpnr-driver.log" 2>&1

grep -E 'Info: Device utilisation|Info:.*LUTFF|Info: Max frequency|ERROR|Error' \
  "$RECORD/validation/async-reset-nextpnr.log" \
  > "$RECORD/validation/async-reset-nextpnr-summary.log" || true

grep -q 'ASYNC_SR' "$RECORD/validation/async_nextpnr_wrapper.fasm"
grep -E 'ASYNC_SR|SET_NORESET' "$RECORD/validation/async_nextpnr_wrapper.fasm" \
  | tee -a "$RECORD/validation/async-reset-nextpnr-summary.log"
echo NEXTPNR_ASYNC_SMOKE_PASS | tee -a "$RECORD/validation/async-reset-nextpnr-summary.log"
