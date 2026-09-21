# zgl-64x64_async asynchronous reset modification

Date: 2026-09-20

Project modified: `/home/zyzhao/FABulous/zgl-64x64_async`

The source projects `/home/zyzhao/FABulous/zgl-64x64` and
`/home/zyzhao/FABulous/zgl-64x64-picorv32-test` were not modified.

## Implemented behavior

Each LUT4AB logic cell now has one extra configuration bit named `ASYNC_SR`.
`SET_NORESET` continues to select reset value 0 or 1.

| ASYNC_SR | SET_NORESET | Mode | Priority |
|---:|---:|---|---|
| 0 | 0 | synchronous clear | `EN` first, then clear |
| 0 | 1 | synchronous set | `EN` first, then set |
| 1 | 0 | asynchronous clear | clear overrides `EN` and clock |
| 1 | 1 | asynchronous set | set overrides `EN` and clock |

This preserves the requested legacy synchronous behavior and adds separate
Yosys mappings for asynchronous clear and asynchronous set, with and without
clock enable.

## Main modified files

- `Tile/LUT4AB/LUT4c_frame_config_dffesr.v`
  - added `ASYNC_SR=19`, expanded the BEL from 19 to 20 configuration bits,
    and implemented asynchronous clear/set priority.
- `Tile/LUT4AB/LUT4AB_ConfigMem.csv`
  - migrated the old 616-bit tile mapping to 624 bits and assigned the eight
    new LC bits to `19,39,59,79,99,119,139,159`.
- `Test/yosys-0.68-maps/ff_map.v`
  - maps positive-edge async clear/set Yosys cells to `LUTFF_AR`, `LUTFF_AS`,
    `LUTFF_EAR`, and `LUTFF_EAS`.
- `Test/yosys-0.68-maps/prims.v`
  - added functional primitive models for these four cell types.
- `Test/build_picorv32.sh`
  - points to this project and allows both synchronous and asynchronous FF
    types during `synth_fabulous` legalization.

Generated FABulous artifacts were rebuilt. The LUT4AB tile now reports 624
configuration bits, and `ASYNC_SR` appears in `bel.v2.txt`, `bel.v3.txt`, and
`bitStreamSpec.csv`. Existing extracted physical PIP delays were restored from
the exact preserved copy `.FABulous/pips.cached-physical.txt` after generation.
All 419,368 timing records in the regenerated `bel.v3.txt` are byte-for-byte
identical to the original `zgl-64x64` timing records; only the new configuration
feature descriptions differ.

## Validation results

- Yosys mapping: passed for `LUTFF_ESR`, `LUTFF_ESS`, `LUTFF_EAR`, and
  `LUTFF_EAS`.
- BEL inference: passed; Yosys represents the combined enable plus asynchronous
  controls as `$dffsre`.
- RTL priority simulation: passed for synchronous clear, asynchronous clear,
  and asynchronous set, including `EN=0` cases.
- nextpnr smoke design: placed and routed successfully; the FASM contains the
  required `ASYNC_SR`/`SET_NORESET` combinations.
- bitgen smoke design: generated `.bin` and `.hex` successfully.

See `validation/` for logs and generated smoke-test files. See `diffs/` for
unified source diffs, `original/` for pre-change source copies, and
`commands.sh` for the repeatable validation commands.

## Physical implementation note

The FABulous/Yosys/nextpnr/bitgen flow is verified. A future ASIC hardening run
must provide an asynchronous set/reset capable register cell or a validated
decomposition for the inferred `$dffsre` behavior.
