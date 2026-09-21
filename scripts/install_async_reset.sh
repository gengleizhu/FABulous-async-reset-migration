#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'usage: %s FABULOUS_ROOT PROJECT\n' "$0" >&2
    exit 2
fi

FAB_ROOT=$(realpath "$1")
PROJECT=$(realpath "$2")
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_ROOT=$(dirname "$SCRIPT_DIR")
PATCH="$PACKAGE_ROOT/patches/async-reset-v2.patch"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RECORD="$PROJECT/change_records/async-reset-migration-$TIMESTAMP"

[[ -d "$FAB_ROOT/.git" ]] || {
    printf 'FABulous Git checkout not found: %s\n' "$FAB_ROOT" >&2
    exit 1
}
[[ -d "$PROJECT/.FABulous" ]] || {
    printf 'FABulous project not found: %s\n' "$PROJECT" >&2
    exit 1
}
[[ "$PROJECT" == "$FAB_ROOT"/* ]] || {
    printf 'Project must be inside the FABulous checkout for patch application.\n' >&2
    exit 1
}
[[ -f "$PATCH" ]] || {
    printf 'Patch not found: %s\n' "$PATCH" >&2
    exit 1
}

REL_PROJECT=${PROJECT#"$FAB_ROOT"/}
TARGET_FILES=(
    Tile/LUT4AB/LUT4c_frame_config_dffesr.v
    Tile/LUT4AB/LUT4AB_ConfigMem.csv
    Test/yosys-0.68-maps/ff_map.v
    Test/yosys-0.68-maps/prims.v
    Test/build_picorv32.sh
)

for relative in "${TARGET_FILES[@]}"; do
    [[ -f "$PROJECT/$relative" ]] || {
        printf 'Required target file not found: %s\n' "$PROJECT/$relative" >&2
        exit 1
    }
done

mkdir -p "$RECORD/original"
for relative in "${TARGET_FILES[@]}"; do
    mkdir -p "$RECORD/original/$(dirname "$relative")"
    cp -a "$PROJECT/$relative" "$RECORD/original/$relative"
done
cp -a "$PATCH" "$RECORD/async-reset-v2.patch"
git -C "$FAB_ROOT" status --short > "$RECORD/before-status.txt"

git -C "$FAB_ROOT" apply --check --directory="$REL_PROJECT" "$PATCH"
git -C "$FAB_ROOT" apply --verbose --directory="$REL_PROJECT" "$PATCH" \
    2>&1 | tee "$RECORD/patch-apply.log"

python3 "$SCRIPT_DIR/migrate_lut4_configmem.py" "$PROJECT" "$RECORD"

# The historical patch records the reference project path. Replace only that
# exact path after a successful compatible patch application.
python3 - "$PROJECT/Test/build_picorv32.sh" "$PROJECT/Test" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
target_test = sys.argv[2]
text = path.read_text(encoding="utf-8")
reference = "/home/zyzhao/FABulous/zgl-64x64_async/Test"
if reference not in text:
    raise SystemExit("reference build path was not found after patch application")
path.write_text(text.replace(reference, target_test), encoding="utf-8")
PY

bash -n "$PROJECT/Test/build_picorv32.sh"

for relative in "${TARGET_FILES[@]}"; do
    mkdir -p "$RECORD/diffs/$(dirname "$relative")"
    diff -u "$RECORD/original/$relative" "$PROJECT/$relative" \
        > "$RECORD/diffs/$relative.diff" || test $? -eq 1
done

sha256sum "${TARGET_FILES[@]/#/$PROJECT/}" > "$RECORD/source-manifest.sha256"
printf 'Async reset sources installed. Regenerate and validate the project next.\n'
printf 'Record: %s\n' "$RECORD"
