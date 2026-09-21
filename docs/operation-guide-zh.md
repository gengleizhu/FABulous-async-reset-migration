# FABulous E_term 与异步复位操作指导

本手册适用于当前虚拟机：

```text
用户：zyzhao
FABulous：/home/zyzhao/FABulous
E_term 功能分支：codex/e-term-template-20260920-175834
E_term 功能提交：26403e8
异步复位参考工程：/home/zyzhao/FABulous/zgl-64x64_async
```

## 1. 环境使用规则

创建工程和运行 EDA 构建时不要叠加 Conda 与 Nix 环境。

### 创建工程

提示符中只保留 Conda 的 `(fabulous)`：

```bash
conda activate fabulous
```

如果提示符同时出现：

```text
(fabulous) [fab-nix] (FABulous-env)
```

先执行一次：

```bash
exit
```

确认已经退出 Nix 子 shell，再执行 `conda activate fabulous`。

### 重新生成和 EDA 验证

使用一个没有激活 Conda 的新终端，或者先执行：

```bash
conda deactivate
unset PYTHONPATH PYTHONHOME LD_LIBRARY_PATH
```

然后再运行 `nix develop`。不要在已激活 Conda 的终端上叠加 Nix。

---

## 2. 让 Conda 使用带 E_term 的 FABulous 源码

### 2.1 切换到 E_term 分支

```bash
cd /home/zyzhao/FABulous
git branch --show-current
git switch codex/e-term-template-20260920-175834
```

切换分支不会删除现有的 Verdi 修改和未跟踪用户工程。如果 Git 报目标文件冲突，应停止操作并先保存冲突文件。

### 2.2 确认公共模板包含 E_term

```bash
cd /home/zyzhao/FABulous

test -f fabulous/fabric_files/FABulous_project_template_common/Tile/E_term/E_term.csv
test -f fabulous/fabric_files/FABulous_project_template_common/Tile/E_term/E_term_switch_matrix.list
test -f fabulous/fabric_files/FABulous_project_template_common/Tile/E_term/gds_config.yaml

grep -n '^Tile,./Tile/E_term/E_term.csv' \
  fabulous/fabric_files/FABulous_project_template_common/fabric.csv
```

三个 `test` 命令应静默成功，`grep` 应输出一条 E_term 注册记录。

### 2.3 解决 Conda 使用旧安装包的问题

先检查当前导入位置：

```bash
conda activate fabulous
python -c 'import fabulous; print(fabulous.__file__)'
```

如果路径位于 `miniforge3/.../site-packages`，安装当前修改后的源码：

```bash
python -m pip install --no-deps -e /home/zyzhao/FABulous
hash -r

python -c 'import fabulous; print(fabulous.__file__)'
```

正确路径应为：

```text
/home/zyzhao/FABulous/fabulous/__init__.py
```

如果暂时不想修改 Conda 环境，可只对单条命令指定源码：

```bash
PYTHONPATH=/home/zyzhao/FABulous \
FABulous create-project /home/zyzhao/FABulous/zgl-demo-Eterm-v2
```

---

## 3. 创建并检查 E_term 工程

不要覆盖已经修改过的工程。先使用一个新目录验证：

```bash
conda activate fabulous
cd /home/zyzhao/FABulous

test ! -e zgl-demo-Eterm-v2
FABulous create-project zgl-demo-Eterm-v2
```

检查生成结果：

```bash
ls -l zgl-demo-Eterm-v2/Tile/E_term

grep -n '^Tile,./Tile/E_term/E_term.csv' \
  zgl-demo-Eterm-v2/fabric.csv
```

必须存在：

```text
Tile/E_term/E_term.csv
Tile/E_term/E_term_switch_matrix.list
Tile/E_term/gds_config.yaml
```

`fabric.csv` 中必须恰好有一条注册记录：

```bash
test "$(grep -c '^Tile,./Tile/E_term/E_term.csv' \
  zgl-demo-Eterm-v2/fabric.csv)" -eq 1
```

### E_term 布局注意事项

公共模板只提供并注册 E_term，不会自动替换默认布局中的 `RAM_IO`。

编辑目标工程的 `fabric.csv` 时：

- 只在适用的东边界内部行放置 `E_term`；
- 西侧相邻 Tile 必须具有匹配的 W1、W2、WW4、W6 通道；
- 不要批量替换角点、RAM_IO 行或通道结构不同的行。

---

## 4. 给新工程迁移异步复位

异步复位是工程级功能，不会因为安装 E_term 自动出现在新工程中。

以下示例假定：

```bash
export FAB_ROOT=/home/zyzhao/FABulous
export TARGET=/home/zyzhao/FABulous/zgl-demo-Eterm-v2
export ASYNC_REF=/home/zyzhao/FABulous/zgl-64x64_async
export ASYNC_RECORD="$ASYNC_REF/change_records/async-reset-v2-20260920"
export NEW_RECORD="$TARGET/change_records/async-reset-migration-$(date +%Y%m%d-%H%M%S)"
```

### 4.1 检查目标和参考记录

```bash
test -d "$TARGET/.FABulous"
test -f "$ASYNC_RECORD/async-reset-v2.patch"
test -f "$ASYNC_RECORD/scripts/migrate_lut4_configmem.py"
mkdir -p "$NEW_RECORD/original/Tile/LUT4AB"
mkdir -p "$NEW_RECORD/original/Test/yosys-0.68-maps"
mkdir -p "$NEW_RECORD/original/Test"
```

### 4.2 保存目标工程原始文件

```bash
cp -a "$TARGET/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  "$NEW_RECORD/original/Tile/LUT4AB/"
cp -a "$TARGET/Tile/LUT4AB/LUT4AB_ConfigMem.csv" \
  "$NEW_RECORD/original/Tile/LUT4AB/"
cp -a "$TARGET/Test/yosys-0.68-maps/ff_map.v" \
  "$NEW_RECORD/original/Test/yosys-0.68-maps/"
cp -a "$TARGET/Test/yosys-0.68-maps/prims.v" \
  "$NEW_RECORD/original/Test/yosys-0.68-maps/"
cp -a "$TARGET/Test/build_picorv32.sh" \
  "$NEW_RECORD/original/Test/"
```

### 4.3 应用异步复位源码补丁

目标工程位于 FABulous Git 仓库内部时执行：

```bash
cd "$FAB_ROOT"
git apply --check \
  --directory="${TARGET#"$FAB_ROOT"/}" \
  "$ASYNC_RECORD/async-reset-v2.patch"

git apply --verbose \
  --directory="${TARGET#"$FAB_ROOT"/}" \
  "$ASYNC_RECORD/async-reset-v2.patch"
```

如果 `--check` 失败，不要强行应用。目标工程的 LUT4AB 或 Yosys mapping 版本可能与参考工程不同，应先人工比较。

### 4.4 迁移 ConfigMem

参考脚本当前写死了 `zgl-64x64_async` 路径，不能直接对新工程执行。先复制一份并把其中的 `project = Path(...)` 改为目标工程路径：

```bash
cp "$ASYNC_RECORD/scripts/migrate_lut4_configmem.py" \
  "$NEW_RECORD/migrate_lut4_configmem.py"

sed -i \
  's|project = Path("/home/zyzhao/FABulous/zgl-64x64_async")|project = Path("/home/zyzhao/FABulous/zgl-demo-Eterm-v2")|' \
  "$NEW_RECORD/migrate_lut4_configmem.py"

python3 "$NEW_RECORD/migrate_lut4_configmem.py"
```

预期输出包含：

```text
mapped config bits: 0..623 exactly once
new ASYNC_SR bits: 19,39,59,79,99,119,139,159
```

如果目标路径不是 `zgl-demo-Eterm-v2`，必须相应修改 `sed` 命令中的目标路径。

### 4.5 调整工程相关构建路径

参考补丁中的 `Test/build_picorv32.sh` 指向 `zgl-64x64_async`。迁移后改为当前目标工程：

```bash
sed -i \
  's|/home/zyzhao/FABulous/zgl-64x64_async/Test|/home/zyzhao/FABulous/zgl-demo-Eterm-v2/Test|' \
  "$TARGET/Test/build_picorv32.sh"

bash -n "$TARGET/Test/build_picorv32.sh"
```

---

## 5. 重新生成 FABulous 产物

使用干净终端，不要激活 Conda：

```bash
conda deactivate 2>/dev/null || true
unset PYTHONPATH PYTHONHOME LD_LIBRARY_PATH

cd /home/zyzhao/FABulous
. /home/zyzhao/.nix-profile/etc/profile.d/nix.sh
export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt

nix develop --offline --no-write-lock-file --accept-flake-config .#nix-env \
  --command bash -c \
  'FABulous -p /home/zyzhao/FABulous/zgl-demo-Eterm-v2 run "load_fabric; gen_all_tile; run_fab"'
```

确认配置位：

```bash
grep -nE 'NoConfigBits|ASYNC_SR|SET_NORESET' \
  "$TARGET/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  "$TARGET/Tile/LUT4AB/LUT4c_frame_config_dffesr.json"

grep -n 'parameter NoConfigBits' \
  "$TARGET/Tile/LUT4AB/LUT4AB.v"

grep -R -m 8 -n 'ASYNC_SR' \
  "$TARGET/.FABulous" "$TARGET/Tile/LUT4AB"
```

LUT4AB Tile 的 `NoConfigBits` 应为 624。

### PIP 延时

只有当目标工程的路由拓扑与已提取延时的参考工程完全一致时，才可以恢复物理 PIP 延时：

```bash
test -f "$TARGET/.FABulous/pips.cached-physical.txt"
cp -f "$TARGET/.FABulous/pips.cached-physical.txt" \
  "$TARGET/.FABulous/pips.txt"
```

如果 fabric 尺寸、布局或 switch matrix 有变化，禁止复制旧 PIP 文件，必须重新完成物理实现和延时提取。

---

## 6. 验证顺序

当前参考工程已经保存完整验证脚本：

```text
/home/zyzhao/FABulous/zgl-64x64_async/change_records/async-reset-v2-20260920/scripts
```

迁移到新工程时，需要把这些脚本中的工程路径替换为 `$TARGET` 后再运行。推荐顺序：

```bash
bash verify_async_reset_sources.sh
bash verify_async_reset_inference.sh
bash run_async_reset_validation.sh
bash run_async_nextpnr_smoke.sh
bash run_async_bitgen_smoke.sh
```

必须出现的通过标记：

```text
MAP_SMOKE_PASS
INFERENCE_PASS
PASS
NEXTPNR_ASYNC_SMOKE_PASS
BITGEN_ASYNC_SMOKE_PASS
```

检查 FASM：

```bash
grep -E 'ASYNC_SR|SET_NORESET' \
  "$NEW_RECORD"/validation/*.fasm
```

---

## 7. 保存迁移记录

```bash
mkdir -p "$NEW_RECORD/diffs"

diff -u \
  "$NEW_RECORD/original/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  "$TARGET/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  > "$NEW_RECORD/diffs/LUT4c_frame_config_dffesr.v.diff" || true

diff -u \
  "$NEW_RECORD/original/Tile/LUT4AB/LUT4AB_ConfigMem.csv" \
  "$TARGET/Tile/LUT4AB/LUT4AB_ConfigMem.csv" \
  > "$NEW_RECORD/diffs/LUT4AB_ConfigMem.csv.diff" || true

sha256sum \
  "$TARGET/Tile/LUT4AB/LUT4c_frame_config_dffesr.v" \
  "$TARGET/Tile/LUT4AB/LUT4AB_ConfigMem.csv" \
  "$TARGET/Test/yosys-0.68-maps/ff_map.v" \
  "$TARGET/Test/yosys-0.68-maps/prims.v" \
  "$TARGET/.FABulous/bel.v3.txt" \
  "$TARGET/.FABulous/pips.txt" \
  "$TARGET/.FABulous/bitStreamSpec.bin" \
  > "$NEW_RECORD/manifest.sha256"
```

---

## 8. 回滚

### 回滚 E_term 工具模板

切换回安装记录中保存的原分支：

```bash
cat /home/zyzhao/FABulous_change_records/e-term-template-20260920-175834/original-branch.txt
git -C /home/zyzhao/FABulous switch xc7-start
```

这只影响以后创建的工程，不会自动删除已经生成工程中的 E_term。

### 回滚目标工程的异步复位

把 `$NEW_RECORD/original` 中保存的五个源文件复制回目标位置，然后重新执行第 5 节的生成流程。不要只恢复 Verilog 而保留 624 位 ConfigMem 映射。

---

## 9. 当前问题的最短修复流程

如果只是解决“新工程没有 E_term”，执行：

```bash
cd /home/zyzhao/FABulous
git switch codex/e-term-template-20260920-175834

conda activate fabulous
python -m pip install --no-deps -e /home/zyzhao/FABulous
hash -r

python -c 'import fabulous; print(fabulous.__file__)'
test ! -e zgl-demo-Eterm-v2
FABulous create-project zgl-demo-Eterm-v2

ls -l zgl-demo-Eterm-v2/Tile/E_term
grep -n '^Tile,./Tile/E_term/E_term.csv' \
  zgl-demo-Eterm-v2/fabric.csv
```

看到三个 E_term 文件和一条 `fabric.csv` 注册记录，即表示修复完成。
