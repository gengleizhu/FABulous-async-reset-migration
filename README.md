# FABulous asynchronous set/reset migration

This repository packages the verified asynchronous set/reset extension from
`zgl-64x64_async` without uploading the complete generated FABulous project.

It adds one `ASYNC_SR` configuration bit to every LUT4AB logic cell while
preserving the existing `SET_NORESET` bit:

| ASYNC_SR | SET_NORESET | Behaviour |
|---:|---:|---|
| 0 | 0 | synchronous clear, gated by EN |
| 0 | 1 | synchronous set, gated by EN |
| 1 | 0 | asynchronous clear, overrides EN and clock |
| 1 | 1 | asynchronous set, overrides EN and clock |

## Contents

- `patches/async-reset-v2.patch`: BEL RTL, Yosys mapping, primitive models,
  and reference build-argument changes.
- `scripts/install_async_reset.sh`: guarded source installer with backups and
  change records.
- `scripts/migrate_lut4_configmem.py`: guarded 616-to-624-bit ConfigMem
  migration.
- `scripts/*_reference.sh`: exact commands used by the verified reference
  project. They retain reference paths for auditability and must be adapted to
  another project before use.
- `tests/`: Yosys mapping, BEL inference, RTL priority, and nextpnr smoke
  designs.
- `docs/`: Chinese implementation/migration guide and command-oriented guide.
- `reference/validation-record.md`: verified reference result summary.

## Apply to a compatible generated project

Start from a separate project copy and a clean FABulous feature branch. Then:

```bash
bash scripts/install_async_reset.sh \
  /home/zyzhao/FABulous \
  /home/zyzhao/FABulous/your-project
```

The installer refuses incompatible ConfigMem input, backs up all five source
files, applies the source patch, migrates the LUT4AB mapping from 616 to 624
bits, updates the reference build path, and writes diffs plus SHA-256 records.

After source installation, regenerate the FABulous artifacts and run the
mapping, inference, RTL, nextpnr, and bitgen checks described in
`docs/operation-guide-zh.md`.

## Important limits

- The patch is compatible with the recorded FABulous project-template version;
  always require `git apply --check` to pass.
- Do not reuse physical PIP delays when fabric topology, layout, or switch
  matrices changed.
- ASIC hardening still needs an asynchronous set/reset capable standard cell
  or a separately validated decomposition.
- Reference scripts contain the original VM paths intentionally; use the
  command guide when migrating to a different project.

## Verified reference

The reference project is
`/home/zyzhao/FABulous/zgl-64x64_async`, with records under
`change_records/async-reset-v2-20260920`.

Validation passed for Yosys mapping, asynchronous-cell inference, RTL priority,
nextpnr placement/routing, FASM features, and bitstream generation. The LUT4AB
mapping contains all indices `0..623` exactly once, and the eight `ASYNC_SR`
indices are `19,39,59,79,99,119,139,159`.
