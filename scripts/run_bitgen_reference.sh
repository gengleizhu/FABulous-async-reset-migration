#!/usr/bin/env bash
set -euo pipefail
PROJECT=/home/zyzhao/FABulous/zgl-64x64_async
RECORD="$PROJECT/change_records/async-reset-v2-20260920"
export PATH=/home/zyzhao/miniforge3/envs/fabulous/bin:/usr/bin:/bin
unset LD_LIBRARY_PATH PYTHONPATH PYTHONHOME
cd "$PROJECT/Test"
task run-bitgen \
  DESIGN=async_nextpnr_wrapper \
  FASM_FILE="$RECORD/validation/async_nextpnr_wrapper.fasm" \
  BIN_FILE="$RECORD/validation/async_nextpnr_wrapper.bin" \
  > "$RECORD/validation/async-reset-bitgen.log" 2>&1

test -s "$RECORD/validation/async_nextpnr_wrapper.bin"
test -s build/async_nextpnr_wrapper.hex
cp -f build/async_nextpnr_wrapper.hex "$RECORD/validation/async_nextpnr_wrapper.hex"
sha256sum \
  "$RECORD/validation/async_nextpnr_wrapper.fasm" \
  "$RECORD/validation/async_nextpnr_wrapper.bin" \
  "$RECORD/validation/async_nextpnr_wrapper.hex" \
  | tee "$RECORD/validation/async-reset-bitgen-summary.log"
echo BITGEN_ASYNC_SMOKE_PASS | tee -a "$RECORD/validation/async-reset-bitgen-summary.log"
