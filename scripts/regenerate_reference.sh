#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/zyzhao/FABulous
PROJECT="$ROOT/zgl-64x64_async"
RECORD="$PROJECT/change_records/async-reset-v2-20260920"
mkdir -p "$RECORD/validation"

cd "$PROJECT"
sha256sum \
  Tile/LUT4AB/LUT4c_frame_config_dffesr.v \
  Tile/LUT4AB/LUT4c_frame_config_dffesr.json \
  Tile/LUT4AB/LUT4AB.v \
  .FABulous/bel.v3.txt \
  .FABulous/pips.txt \
  .FABulous/pips.cached-physical.txt \
  .FABulous/bitStreamSpec.bin \
  > "$RECORD/validation/generated-files-before.sha256"

# pips.cached-physical.txt is an exact preserved copy of the active physical-delay pips.
test "$(sha256sum .FABulous/pips.txt | cut -d' ' -f1)" = \
     "$(sha256sum .FABulous/pips.cached-physical.txt | cut -d' ' -f1)"

. /home/zyzhao/.nix-profile/etc/profile.d/nix.sh
export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
cd "$ROOT"
nix develop --offline --no-write-lock-file --accept-flake-config .#nix-env \
  --command bash -c \
  'FABulous -p /home/zyzhao/FABulous/zgl-64x64_async run "load_fabric; gen_all_tile; run_fab"' \
  > "$RECORD/regenerate-fabric.log" 2>&1

cd "$PROJECT"

# run_fab regenerates routing topology with default delay values. Routing did not
# change, so restore the already extracted physical-delay model.
cp -f .FABulous/pips.cached-physical.txt .FABulous/pips.txt

sha256sum \
  Tile/LUT4AB/LUT4c_frame_config_dffesr.v \
  Tile/LUT4AB/LUT4c_frame_config_dffesr.json \
  Tile/LUT4AB/LUT4AB.v \
  .FABulous/bel.v3.txt \
  .FABulous/pips.txt \
  .FABulous/bitStreamSpec.bin \
  > "$RECORD/validation/generated-files-after.sha256"

{
  echo '=== primitive metadata ==='
  grep -nE 'NoConfigBits|ASYNC_SR|SET_NORESET' \
    Tile/LUT4AB/LUT4c_frame_config_dffesr.v \
    Tile/LUT4AB/LUT4c_frame_config_dffesr.json
  echo '=== tile total ==='
  grep -n 'parameter NoConfigBits' Tile/LUT4AB/LUT4AB.v
  echo '=== generated nextpnr/bitstream references ==='
  grep -R -m 8 -n 'ASYNC_SR' .FABulous Tile/LUT4AB 2>/dev/null || true
  echo '=== physical pips preserved ==='
  sha256sum .FABulous/pips.txt .FABulous/pips.cached-physical.txt
} > "$RECORD/validation/regeneration-check.log"

cat "$RECORD/validation/regeneration-check.log"
