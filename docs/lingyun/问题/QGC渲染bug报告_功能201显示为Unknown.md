# QGC Bug 报告：自定义功能 201（Blower1）在 QGC 中渲染为 "Unknown: 201"，而同批拆分的 202~208 渲染正常

> 本文档面向 QGroundControl 开发者/AI。内容包含：完整背景、症状、排除法排查过程、固件侧全部证据（可直接复用的数据文件与复现步骤），以及建议的检查方向。
> 我们侧（PX4 固件）六层验证全部正确，强烈怀疑问题在 QGC 端的元数据解析/渲染，但无法进一步定位 QGC 内部逻辑，故提交此报告。

---

## 1. 环境

| 项目 | 值 |
|------|-----|
| 飞控 | CUAV X25-EVO（STM32H743，无 IOMCU） |
| 固件 | PX4 v1.17.0 定制版（git 描述 v1.6.2-25695，含 airship 机架 2058_lingyun01；QGC 显示"固件版本 1.17.0 / 自定义固件 版本 1.0.0"） |
| QGC | QGroundControl Daily（Linux x64，中文界面） |
| 连接方式 | USB（/dev/ttyACM0），QGC 通过 MAVLink FTP 拉取元数据 |
| 涉及参数 | `PWM_MAIN_FUNC1~16`（输出口功能绑定） |

## 2. 背景：固件侧的改动

为使输出功能名语义化，我们将 PX4 v1.17 原生 `output_functions.yaml` 中的 **Servo 组**：

```yaml
Servo:
  start: 201
  count: 8
```

拆分为 8 个**独立单值条目**（数值不变，仅命名粒度变化）：

```yaml
Blower1: 201   # 副囊1 风机
Valve1: 202    # 副囊1 阀门
Blower2: 203   # 副囊2 风机
Valve2: 204    # 副囊2 阀门
Blower3: 205   # 主囊3 风机
Valve3: 206    # 主囊3 阀门
Blower4: 207   # 主囊4 风机
Valve4: 208    # 主囊4 阀门
```

同步修改的 C++ 引用（13 处，5 个文件）：`OutputFunction::Servo1 → OutputFunction::Blower1`、`OutputFunction::ServoMax → OutputFunction::Valve4`，涉及 `FunctionServos.hpp`、`mixer_module.cpp`、`actuator_test.cpp/hpp`、`PWMOut.cpp`、`px4io.cpp`。另将 `control_allocator/module.yaml` 中 `mixer.actuator_types.servo.functions` 从 `'Servo'` 改为 `'Blower1'`，并让 `generate_actuators_metadata.py` 兼容单值功能条目（`isinstance(output_function, int)` 时视为 `{start: v, count: 1}`）。

功能值 **201~208 保持连续不变**，功能运行时行为完全正常。

## 3. 症状

QGC → Vehicle Configuration → **Actuators** 页与 **Parameters** 页中：

| 通道 | 绑定功能值 | QGC 显示 | 预期显示 |
|------|-----------|---------|---------|
| MAIN 1（及 CAP 1，重复绑定同一功能） | **201** | **"未知： 201"（Unknown: 201）** ❌ | Blower 1 |
| MAIN 2（及 CAP 2） | 202 | Valve1 ✓ | Valve 1 |
| MAIN 3（及 CAP 3） | 203 | Blower2 ✓ | Blower 2 |
| MAIN 4（及 CAP 4） | 204 | Valve2 ✓ | Valve 2 |
| MAIN 5~8 | 205~208 | Blower3/Valve3/Blower4/Valve4 ✓ | Blower 3~Valve 4 |

关键特征：

1. **唯独值 201 渲染失败**，202~208（同一批拆分产生的条目）全部正常。
2. Actuators 页 MAIN1 的 Function **下拉展开后，选项列表中 201 这一项的显示文字本身就是 "Unknown: 201"**，且排序被放到列表最末尾（RPM Input(2070) 之后）——即 QGC 解析后该条目的 **label 已经丢失**，而非"当前值匹配失败"。
3. 已尝试：重启 QGC、清除 `~/.cache/QGroundControl*` 后重连——无效。

**历史症状（改动前，供对照）**：拆分前的固件（原生 Servo1~8 命名，FUNC1~8=201~208）在**同一台 QGC** 上，MAIN1~8 的 Function 下拉选项里同样**没有** "Servo 1~8" 的正常显示，当时全部显示为 "Unknown: 201~208"。即：**无论我们是否拆分命名，QGC 一直没有正确渲染过 201~208 区间的功能 label**——Motor 组（101~112）与更早/更晚的功能组渲染均正常。

## 4. 排查过程与证据链（六层全部验证）

### 证据 1：功能定义源

`src/lib/mixer_module/output_functions.yaml` 中 `Blower1: 201` ... `Valve4: 208` 定义正确（见第 2 节）。

### 证据 2：编译生成的 C++ 枚举与功能行为

`generate_function_header.py` 从 yaml 生成 `OutputFunction` 枚举，编译通过；运行时功能行为正常：绑定 201 的输出口物理输出正确（实测 PWM 驱动外部 24V DCDC 控制端通断受控）。

### 证据 3：编译产物——参数元数据 `parameters.json`

`PWM_MAIN_FUNC1` 的 `values` 数组共 **55 条**，完整且规范（节选，完整 55 条可复现导出）：

```json
[
  {"description": "Disabled",    "value": 0},
  {"description": "Constant Min","value": 1},
  {"description": "Constant Max","value": 2},
  {"description": "Motor 1",     "value": 101},
  ...
  {"description": "Motor 12",    "value": 112},
  {"description": "Blower1",     "value": 201},
  {"description": "Valve1",      "value": 202},
  {"description": "Blower2",     "value": 203},
  {"description": "Valve2",      "value": 204},
  {"description": "Blower3",     "value": 205},
  {"description": "Valve3",      "value": 206},
  {"description": "Blower4",     "value": 207},
  {"description": "Valve4",      "value": 208},
  {"description": "Peripheral via Actuator Set 1", "value": 301},
  ...
  {"description": "Camera Trigger", "value": 2000},
  {"description": "Camera Capture", "value": 2032},
  {"description": "PPS Input",      "value": 2064},
  {"description": "RPM Input",      "value": 2070}
]
```

`Blower1` 条目结构与 `Valve1` 等完全一致（`description` + `int value`），无缺字段。

### 证据 4：编译产物——执行器元数据 `actuators.json`

`functions_v1` 为 dict，键为功能值字符串。完整键列表（顺序即文件内顺序，数值升序）：

```
"0","1","2","101","102",...,"112","201","202","203","204","205","206","207","208",
"301",...,"306","400","401","402",...,"412","420","421","422","430","440","450",...,"453",
"2000","2032","2064","2070"
```

各条目结构完全一致：

```json
"101": {"label": "Motor 1"},
"201": {"label": "Blower1"},
"202": {"label": "Valve1"},
...
"208": {"label": "Valve4"}
```

**201 条目与正常渲染的 202 条目结构零差异。**

### 证据 5：ROMFS 打包产物（固件内实际携带的文件）

`build/.../etc/extras/` 下：

- `actuators.json.xz`
- `parameters.json.xz`

解压后内容与证据 3/4 完全一致：`PWM_MAIN_FUNC1.values` 含 201~208 全部条目；`functions_v1` 含 201→Blower1。

### 证据 6：飞控上实际存储的文件（MAVLink FTP 拉取）

通过 MAVLink FTP 从**运行中的飞控**拉取 `/etc/extras/parameters.json.xz`：

```
飞控上文件：67332 字节  md5 = 5e43a073021ca95b2c41074b210319a3
编译产物：  67332 字节  md5 = 5e43a073021ca95b2c41074b210319a3
→ 逐字节一致
```

解压后复检：`PWM_MAIN_FUNC1.values` 中 201~208 全部在列，201 条目原文 `{"description": "Blower1", "value": 201}`。

### 证据 7：运行时参数值与物理行为

- MAVLink 参数协议读回 `PWM_MAIN_FUNC1 = 201`（INT32 位模式编码验证）。
- 绑定 201 的物理口输出行为完全正常（PWM 驱动 24V DCDC 控制端，通断实测受控）。

## 5. 结论

1. **PX4 固件侧（我们侧）数据链路六层全部正确**：yaml 源 → C++ 枚举 → parameters.json → actuators.json → ROMFS 打包 → 飞控存储，`201 → Blower1` 的定义与数据逐层一致，且通过 FTP 与 MD5 证明 QGC 可拉取到的内容就是这份正确数据。
2. **QGC 拿到了完整正确的元数据**（202~208 的新 label 都渲染出来了，证明拉取与大部分解析成功），**唯独值 201 的 label 渲染为 Unknown**。
3. 该问题**早于我们的改名改动**：拆分前原生 `Servo: {start:201,count:8}` 命名时，201~208 同样全部显示 Unknown。即：**QGC 对 PX4 参数/执行器元数据中 201~208 这段连续功能值的 label 解析/渲染存在稳定缺陷**。

## 6. 给 QGC 开发者的检查建议

结合症状特征（"同批拆分条目中唯独第一个新条目丢 label"、"Unknown 条目排序沉底"），建议检查：

1. **`functions_v1`（dict，键为功能值字符串 "201"~"208"）的解析路径**：是否存在对 dict 首个匹配条目的跳过/覆盖逻辑（例如解析时先消费一个哨兵条目）。
2. **参数元数据 `values` 数组 → Fact enum 映射**：`{"description": "Blower1", "value": 201}` 的 value 为 int；确认解析后建立 value→description 映射时无类型/首条目处理差异。
3. **缓存 key**：QGC 元数据缓存的 key 是否包含固件内容指纹。我们的固件版本串恒为"custom firmware 1.0.0"（多次刷不同内容），若缓存 key 仅含版本串，存在陈旧缓存复用风险——但本例中 202~208 能渲染出新 label，说明缓存至少部分刷新了，此条优先级较低。
4. **"Unknown: N" 的生成路径**：QGC 中 label 查找失败时的 fallback 格式化代码处下断点，回溯该 functions map 的构建过程，即可直接看到 201 条目是在哪一步丢失的。

## 7. 复现要点（QGC 侧）

1. 使用本报告附带/描述的固件（任意将 `output_functions.yaml` 中 201~208 改为独立命名功能的 PX4 v1.17 构建应可复现）。
2. 连接后进入 Vehicle Configuration → Actuators，将任一输出口 Function 设为值 201 的功能（Blower1）。
3. 观察 Function 下拉：该项显示 "Unknown: 201" 且排序沉底；Parameters 页同名参数 Value 列同样显示 "Unknown: 201"。
4. 对照组：值 202~208 的功能（Valve1 等）渲染正常。

## 8. 附件（我方构建产物，可直接分析）

- `build/<target>/parameters.json` — 参数元数据（含 PWM_MAIN_FUNC1.values 55 条）
- `build/<target>/parameters.json.xz` — 固件 ROMFS 打包版（飞控上同名文件 MD5 一致：`5e43a073021ca95b2c41074b210319a3`）
- `build/<target>/actuators.json` — 执行器元数据（functions_v1 含 "201": {"label": "Blower1"}）
- `build/<target>/etc/extras/actuators.json.xz` — ROMFS 打包版
- `src/lib/mixer_module/output_functions.yaml` — 拆分后的功能定义
