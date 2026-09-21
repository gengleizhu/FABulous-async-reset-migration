# FABulous 异步复位与 E_term 实现及迁移指南

## 1. 目标与当前状态

本次工作包含两个相互独立、可以组合使用的功能：

| 功能 | 修改层级 | 当前载体 | 对后续工程的影响 |
|---|---|---|---|
| E_term 东侧终结 Tile | FABulous 工具仓库的公共工程模板 | `/home/zyzhao/FABulous` 的 `codex/e-term-template-20260920-175834` 分支，提交 `26403e8` | 以后执行 `FABulous create-project` 时自动复制并注册 E_term |
| LUT4AB 同步/异步置位复位 | 已生成 fabric 工程 | `/home/zyzhao/FABulous/zgl-64x64_async` | 只影响该工程；迁移到其他 fabric 时需要应用源码修改、迁移配置位并重新生成 FABulous 元数据 |

两者没有配置位或 RTL 冲突。推荐先给 FABulous 工具仓库安装 E_term 模板支持，再创建目标工程，最后在目标工程中迁移异步复位功能。

---

## 2. 异步复位功能

### 2.1 设计行为

每个 `LUT4c_frame_config_dffesr` 新增一个配置位 `ASYNC_SR`。原配置位 `SET_NORESET` 继续选择清零或置位。

| `ASYNC_SR` | `SET_NORESET` | 模式 | 优先级 |
|---:|---:|---|---|
| 0 | 0 | 同步清零 | `EN` 优先；只有 `EN=1` 时同步清零 |
| 0 | 1 | 同步置位 | `EN` 优先；只有 `EN=1` 时同步置位 |
| 1 | 0 | 异步清零 | 清零高于 `EN` 和时钟 |
| 1 | 1 | 异步置位 | 置位高于 `EN` 和时钟 |

同步模式保留原工程的行为；异步模式下，即使 `EN=0`，有效的异步控制仍立即更新寄存器。

### 2.2 BEL RTL 修改

文件：

```text
Tile/LUT4AB/LUT4c_frame_config_dffesr.v
```

主要修改：

1. `NoConfigBits` 从 19 增加到 20。
2. 新增配置位索引 `ASYNC_SR=19`。
3. 从配置位导出：

   ```verilog
   sync_sr     = SR & ~ASYNC_SR;
   async_clear = SR &  ASYNC_SR & ~SET_NORESET;
   async_set   = SR &  ASYNC_SR &  SET_NORESET;
   ```

4. 时序块改为同时响应时钟、异步清零和异步置位：

   ```verilog
   always @(posedge UserCLK or posedge async_clear or posedge async_set)
   ```

5. RTL 优先级为：异步清零、异步置位、`EN`、同步置位/复位或正常数据。

### 2.3 LUT4AB 配置存储映射

文件：

```text
Tile/LUT4AB/LUT4AB_ConfigMem.csv
```

LUT4AB 中有 8 个逻辑单元。每个单元由 19 位扩展为 20 位，因此 Tile 配置位总数从 616 增加到 624。

8 个新增 `ASYNC_SR` 位的逻辑索引为：

```text
19, 39, 59, 79, 99, 119, 139, 159
```

迁移规则：

- 原索引小于 152 的配置位，按照其所属 LC 从 19 位分组迁移到 20 位分组；
- 原索引大于等于 152 的 `InPass` 和 switch-matrix 配置位统一增加 8；
- 从原来未使用的物理 frame 位置中分配 8 个位置给新配置位；
- 迁移后必须确认 `0..623` 每个逻辑配置位恰好出现一次。

迁移脚本：

```text
migrate_lut4_configmem.py
```

不要只修改 BEL 的 `NoConfigBits` 而不更新 `LUT4AB_ConfigMem.csv`，否则生成的 bitstream 配置索引会错位。

### 2.4 Yosys 映射和仿真 primitive

修改文件：

```text
Test/yosys-0.68-maps/ff_map.v
Test/yosys-0.68-maps/prims.v
Test/build_picorv32.sh
```

新增映射：

| Yosys 内部单元 | FABulous primitive | 功能 |
|---|---|---|
| `$_DFF_PP0_` | `LUTFF_AR` | 无 EN、异步清零 |
| `$_DFF_PP1_` | `LUTFF_AS` | 无 EN、异步置位 |
| `$_DFFE_PP0P_` | `LUTFF_EAR` | 带 EN、异步清零 |
| `$_DFFE_PP1P_` | `LUTFF_EAS` | 带 EN、异步置位 |

`prims.v` 为四种 primitive 增加功能模型；`build_picorv32.sh` 的 `synth_fabulous` 参数允许同步和异步 FF 类型通过 legalization。

当前 nextpnr FABulous 后端已经识别 `LUTFF_AR`、`LUTFF_AS`、`LUTFF_EAR` 和 `LUTFF_EAS`，并能生成 `ASYNC_SR` FASM feature，因此没有修改 nextpnr 源码。

### 2.5 重新生成

修改完成后必须重新生成 Tile、fabric、nextpnr 模型和 bitstream 规格：

```bash
cd /home/zyzhao/FABulous
. /home/zyzhao/.nix-profile/etc/profile.d/nix.sh
nix develop --offline --no-write-lock-file --accept-flake-config .#nix-env \
  --command bash -c \
  'FABulous -p /path/to/target_project run "load_fabric; gen_all_tile; run_fab"'
```

当前 `zgl-64x64_async` 的路由拓扑没有变化，因此生成后恢复了原先提取的物理 PIP 延时：

```bash
cp .FABulous/pips.cached-physical.txt .FABulous/pips.txt
```

这个操作只适用于路由拓扑和物理实现完全不变的工程。如果迁移目标改变了 fabric 尺寸、Tile 布局或 switch matrix，不能复用旧 PIP 延时，必须重新完成物理实现和延时提取。

### 2.6 验证结果

当前工程已完成：

- Yosys 同步清零、同步置位、异步清零、异步置位映射检查；
- BEL 推断检查，组合 EN 与异步控制被推断为异步时序单元；
- RTL 优先级仿真，包含 `EN=0` 时的异步清零和异步置位；
- nextpnr 放置布线，FASM 中出现正确的 `ASYNC_SR`/`SET_NORESET` 组合；
- bitgen 生成 `.bin` 和 `.hex`；
- 624 位配置映射完整性检查；
- 419,368 条已有 BEL timing 记录保持不变。

物理实现注意事项：逻辑综合、布局布线和 bitstream 流程已经验证；后续 ASIC hardening 必须提供真正支持异步置位/复位的寄存器单元，或者验证等价分解电路。

---

## 3. E_term Tile 功能

### 3.1 修改层级

E_term 安装在 FABulous 的公共工程模板中：

```text
fabulous/fabric_files/FABulous_project_template_common/
```

因此安装后，每次执行 `FABulous create-project` 都会得到 E_term 文件和 `fabric.csv` 注册项。它不会自动改变默认示例 fabric 的 Tile 排列。

### 3.2 新增文件

```text
Tile/E_term/E_term.csv
Tile/E_term/E_term_switch_matrix.list
Tile/E_term/gds_config.yaml
```

并在公共模板的 `fabric.csv` 中新增：

```csv
Tile,./Tile/E_term/E_term.csv
```

### 3.3 路由语义

`E_term` 用于 fabric 东边界，将向东离开阵列的 routing wire 折返并终结。支持的通道为：

| 西侧输入 | 东向 wire | 数量 | switch matrix 处理 |
|---|---|---:|---|
| `W1BEG` | `E1END` | 4 | 反转索引 |
| `W2BEG` | `E2MID` | 8 | 反转索引 |
| `W2BEGb` | `E2END` | 8 | 反转索引 |
| `WW4BEG` | `EE4END` | 16 | 反转索引 |
| `W6BEG` | `E6END` | 12 | 反转索引 |

例如：

```text
W1BEG[0|1|2|3] -> E1END[3|2|1|0]
```

放置 E_term 时，西侧相邻核心 Tile 的 W1、W2、WW4、W6 通道名称、跨度和数量必须与 E_term 定义一致。

### 3.4 默认布局策略

公共模板只注册 E_term，不自动替换示例布局。当前默认示例东边界使用 `RAM_IO`，自动替换会改变原示例含义并可能造成通道不匹配。

在具体工程中，应只把适用的东边界内部行替换为 `E_term`；角点、RAM_IO 行或通道定义不同的行应保持其专用终结 Tile。

### 3.5 测试和环境限制

测试检查：

- `create-project` 生成三个 E_term 文件；
- `fabric.csv` 恰好注册一次 E_term；
- Tile 声明和 switch matrix 引用正确；
- 五组折返映射完整。

虚拟机中的标准 pytest 在收集阶段受到现有 Nix/Tkinter 与系统 GLIBC 版本不匹配的影响：Nix Tcl/Tk 需要 `GLIBC_2.38`。这不是 E_term 失败。迁移包使用相同的 FABulous `create_project` 实现，但跳过 GUI REPL/Tkinter 初始化，验证已经通过。

---

## 4. 两项功能的组合迁移流程

### 4.1 准备干净基线

建议保留上游 FABulous 和用户生成工程的独立副本：

```bash
git -C /path/to/FABulous status --short
git -C /path/to/FABulous switch -c feature/combined-async-reset-e-term
```

如果工作区已有修改，先记录 `git status`、未暂存 diff 和 untracked 文件清单。不要把 Verdi 会话、生成工程或其他用户文件一起提交。

### 4.2 安装 E_term 公共模板

迁移仓库：

```text
https://github.com/gengleizhu/FABulous-E_term-template
```

在虚拟机执行：

```bash
git clone https://github.com/gengleizhu/FABulous-E_term-template.git
bash FABulous-E_term-template/scripts/install_in_vm.sh /path/to/FABulous
```

安装器会创建时间戳分支、保存变更前状态、应用补丁、只提交 E_term 相关文件，并执行生成工程验证。

当前已安装记录：

```text
FABulous 分支：codex/e-term-template-20260920-175834
FABulous 提交：26403e8
迁移仓库最新提交：7d7cc86
```

### 4.3 创建目标工程

完成 E_term 安装后再创建工程：

```bash
FABulous create-project /path/to/new_project
```

确认：

```bash
test -f /path/to/new_project/Tile/E_term/E_term.csv
grep -n '^Tile,./Tile/E_term/E_term.csv' /path/to/new_project/fabric.csv
```

然后根据目标 fabric 的东边界通道，把适用位置改成 `E_term`。

### 4.4 迁移异步复位

异步复位当前是工程级修改。以新工程副本为目标：

1. 备份以下文件：

   ```text
   Tile/LUT4AB/LUT4c_frame_config_dffesr.v
   Tile/LUT4AB/LUT4AB_ConfigMem.csv
   Test/yosys-0.68-maps/ff_map.v
   Test/yosys-0.68-maps/prims.v
   Test/build_picorv32.sh
   ```

2. 应用 `async_reset_v2.patch` 中的 BEL、Yosys mapping、primitive 和构建参数修改。
3. 运行参数化后的 `migrate_lut4_configmem.py`，把脚本中的工程路径改成目标工程路径。
4. 确认 8 个 `ASYNC_SR` 索引和 `0..623` 完整映射。
5. 重新生成 FABulous 产物。
6. 路由拓扑未变时恢复已验证的物理 PIP 延时；否则重新提取延时。
7. 依次执行映射、推断、RTL 仿真、nextpnr 和 bitgen 验证。

当前异步复位脚本和补丁记录使用绝对路径 `/home/zyzhao/FABulous/zgl-64x64_async`，迁移到其他工程前必须参数化 `PROJECT`、`FABULOUS_ROOT` 和 `RECORD`，不能原样在不同路径执行。

### 4.5 推荐的可迁移包结构

```text
FABulous-combined-migration/
├── README.md
├── e_term/
│   ├── 0001-e-term-template.patch
│   ├── install_in_vm.sh
│   └── verify_template.py
└── async_reset/
    ├── async_reset_v2.patch
    ├── migrate_lut4_configmem.py
    ├── regenerate.sh
    ├── tests/
    │   ├── async_reset_bel_tb.v
    │   ├── async_reset_map_smoke.v
    │   └── async_nextpnr_wrapper.v
    └── verify_all.sh
```

所有脚本应接收路径参数，而不是写死用户名和工程名：

```bash
bash install_async_reset.sh \
  --fabulous-root /path/to/FABulous \
  --project /path/to/generated_project \
  --record /path/to/change_records/run-id
```

---

## 5. 验收清单

### E_term

- [ ] 新工程包含 `Tile/E_term` 下三个文件。
- [ ] `fabric.csv` 恰好注册一次 E_term。
- [ ] 东边界放置位置与相邻 Tile 的 W1/W2/WW4/W6 通道匹配。
- [ ] `gen_all_tile` 和 `run_fab` 成功。

### 异步复位

- [ ] 每个 LUT4AB LC 的配置位由 19 增至 20。
- [ ] LUT4AB 总配置位为 624。
- [ ] `ASYNC_SR` 位为 `19,39,59,79,99,119,139,159`。
- [ ] ConfigMem 的 `0..623` 每个索引恰好出现一次。
- [ ] Yosys 能映射 `LUTFF_AR/AS/EAR/EAS`。
- [ ] 异步控制在 `EN=0` 时仍生效。
- [ ] FASM 包含正确的 `ASYNC_SR` 和 `SET_NORESET`。
- [ ] nextpnr 成功完成放置布线。
- [ ] bitgen 成功产生非空 `.bin` 和 `.hex`。
- [ ] 物理 PIP 延时来源明确且与当前路由拓扑一致。

### 记录与回滚

- [ ] 保存修改前源码、补丁、命令、日志和 SHA-256 manifest。
- [ ] 功能修改位于独立 Git 分支和独立提交。
- [ ] 未提交无关 Verdi 文件、用户工程和凭据。
- [ ] E_term 可通过切回原 FABulous 分支回滚。
- [ ] 异步复位可通过恢复 `change_records/.../original` 中的五个源文件并重新生成回滚。

---

## 6. 当前记录位置

### E_term

```text
虚拟机功能分支：/home/zyzhao/FABulous
修改记录：/home/zyzhao/FABulous_change_records/e-term-template-20260920-175834
迁移仓库：/home/zyzhao/FABulous-E_term-template
GitHub：https://github.com/gengleizhu/FABulous-E_term-template
```

### 异步复位

```text
目标工程：/home/zyzhao/FABulous/zgl-64x64_async
修改记录：/home/zyzhao/FABulous/zgl-64x64_async/change_records/async-reset-v2-20260920
原始未修改工程：/home/zyzhao/FABulous/zgl-64x64
```

异步复位记录目录包含原始文件、统一 diff、重建脚本、验证设计、日志、生成文件校验值和最终 manifest，是迁移和审计时的权威记录。
