# PX4 侧修改单：Servo 输出组元数据完整化 + 执行器测试值域修正

> **文档目的**: 修复"第三方/官方 QGC 打开灵云01 时 Blower/Valve 功能显示 Unknown、
> 执行器测试滑块初始位置在中间"两个问题。根因在 PX4 固件的元数据源文件，
> **修改后全 GCS 通用**，不再依赖灵云定制 QGC 的客户端补丁。
>
> **提出方**: QGC 项目（2026-09-09）
> **影响文件**（均在 PX4-Autopilot 仓库）:
> 1. `src/lib/mixer_module/output_functions.yaml`
> 2. `src/modules/control_allocator/module.yaml`
> **重编译要求**: 是（重新生成 actuators.json 与功能枚举头文件）
> **关联文档**: `11_浮力NAMED_VALUE_FLOAT四囊独立广播契约升级.md`（QGC→PX4 侧另一张修改单）

---

## 1. 现象（2026-09-09 官方 QGC 实测）

| 现象 | 灵云定制 QGC | 官方 QGC |
|------|-------------|----------|
| MAIN/CAP 通道 Function 显示 | Blower1~Valve4 正常 | **Unknown: 201/202/...（部分通道）** |
| 执行器测试滑块初始位置 | 贴底（0，安全位）| **中间（中位 PWM）** |

## 2. 根因（均已源码取证）

### 2.1 `control_allocator/module.yaml` — servo 组 `functions` 仅声明首功能

```yaml
        servo:
            functions: 'Blower1'   # ← 仅指向首功能 201
```

**机制**（`Tools/module_config/generate_actuators_metadata.py` L305-313）:
`functions` 为单字符串时，查 `output_functions.yaml` 的 common 组；
`Blower1: 201` 是单值 int → 展开 `{'start': 201, 'count': 1}` →
生成的 actuators.json 中该输出组 **function-min=201, function-max=201**（范围塌缩）。
202-208 不在元数据范围内 → 标准 QGC 的 updateFunctionMetadata 会把
"几何占用但元数据范围外"的功能值删除 → UI 显示 Unknown。

### 2.2 `control_allocator/module.yaml` — servo 组测试值域为伺服语义

```yaml
            actuator_testing_values:
                min: -1
                max: 1
                default: 0    # ← 0 在 [-1,1] 的正中 = 中位 PWM
```

servo 组的执行器实际是**风机(占空比)/阀门(开关)**，不是双向伺服。
`default: 0` = 中位 PWM，导致官方 QGC 测试滑块初始停在中间，
且打开测试开关瞬间输出中位 PWM（对常闭阀=关，对风机=半速错误输出）。

## 3. 修改单

### 3.1 `src/lib/mixer_module/output_functions.yaml` — 新增整组定义

**位置**: `functions: common:` 区，紧跟 `Valve4: 208` 之后新增（**保留** Blower1~Valve4 单值定义，
`FunctionServos.hpp` 的 `OutputFunction::Blower1` 等枚举与 `static_assert` 依赖它们）:

```yaml
    Blower1: 201
    Valve1: 202
    Blower2: 203
    Valve2: 204
    Blower3: 205
    Valve3: 206
    Blower4: 207
    Valve4: 208
    # 灵云01: 整组引用名(供 module.yaml actuator_types.functions 使用, 覆盖201-208全部功能)
    BalloonActuators:
      start: 201
      count: 8
```

说明: 新组经 `generate_function_header.py` 会生成 `OutputFunction::BalloonActuators1~8`
枚举（数值 201-208，与 Blower1~Valve4 同值不同名，C++ 枚举允许同名重复值），
不影响 `FunctionServos.hpp` 的 static_assert 与既有代码。

### 3.2 `src/modules/control_allocator/module.yaml` — servo 组改整组引用 + 修正值域

```yaml
        servo:
            functions: 'BalloonActuators' # 灵云01: 整组引用201-208(风机4+阀门4), 元数据范围完整化, 任意GCS可识别
            actuator_testing_values:
                min: 0                    # 0%占空 = PWM低 = 风机停/阀关(安全位, 滑块贴底)
                max: 1
                default: 0                # 打开测试开关瞬间输出0(安全), 官方QGC滑块亦默认贴底
```

变更点:
- `functions: 'Blower1'` → `'BalloonActuators'`（function-min/max 变为 **201/208**）
- `min: -1` → `0`；`max: 1` 保持；`default: 0` 语义从"中位"变为"安全停"（滑块贴底）

## 4. 验收标准

1. 编译无错误（注意 `generate_function_header.py` 重新生成功能枚举）
2. 固件启动后，检查 `actuators.json` 元数据：servo 组 `function-min=201`、`function-max=208`（范围完整化达成）
3. 执行器测试（Enable sliders 后，灵云定制 QGC）:
   - 全部滑块初始位置**贴底**（0）
   - 滑条值域 0~1（不再有负半程）
   - 打开开关瞬间风机/阀门输出为安全位
4. 灵云定制 QGC 回归: Blower/Valve 显示、四囊面板、测试滑块贴底行为不变

### 4.1 ⚠️ 明确不达成的预期（2026-09-09 修订）

**"官方 QGC / LGC 显示 Unknown" 的现象不会因本修改单消失，反而会扩大**。
原因: QGC upstream 的元数据清理逻辑为
`范围内(201~208) && 未画在控制分配几何上 → 删除该功能的显示名`。
气囊执行器本就不在几何中，因此:

| GCS | 元数据版本 | Unknown 范围 |
|-----|-----------|-------------|
| LGC / 官方 QGC | 旧表（201~201, 范围标注漏 202-208）| 仅 201（202-208 因范围标注漏洞幸免）|
| LGC / 官方 QGC | **新表（201~208, 本修改单）** | **201~208 全部**（漏洞消失, 显示恶化）|
| 灵云定制 QGC（含占用保护补丁）| 任意 | 无（"输出通道在用的功能永不删"）|

**彻底解决 Unknown 显示的唯一路径**: 将灵云 QGC 的 `assignedFunctions` 占用保护补丁
（`src/Vehicle/Actuators/Actuators.cc` "Functions currently assigned to any output
channel must never be removed"）提 PR 至 QGC upstream；或统一使用灵云定制 QGC 作为标准地面站。
本修改单仍应实施——元数据范围完整化是正确性基础，且是 upstream 补丁生效的前提
（范围塌缩时 upstream 补丁也无法显示 202-208 的正确命名）。

## 5. 风险与回退

| 风险 | 评估 | 措施 |
|------|------|------|
| UAVCAN_ENABLE=3 时 UAVCAN ESC 输出组同样引用功能 101-110 | 无关（本单只动 servo 组 201-208 与测试值域）| 不涉及 |
| `min: -1 → 0` 改变测试滑条值域 | 仅影响 Actuator Testing，正式控制输出(PWM_MAIN_MIN/MAX/DIS)不变 | 无需回退 |
| 生成器对同名值枚举的处理 | C++ 枚举允许同值异名; static_assert 用 Valve4-Blower1 差值, 不受新组影响 | 编译期即验证 |
| 回退 | 还原两文件改动重编译即可; QGC 侧定制补丁(Actuators.cc/ActuatorSlider.qml)可继续作为客户端双保险保留 | — |

## 6. QGC 侧配套现状（备案）

- `Actuators.cc` updateFunctionMetadata: "输出通道占用功能永不删除"补丁（`assignedFunctions`）
  ——这是 LGC/官方 QGC 中 Unknown 显示问题的客户端解法；upstream 无此逻辑
- `ActuatorSlider.qml` defaultVal=min 贴底定制保留（与固件修复后的行为一致）
- QGC 四囊面板/浮力 HUD 不受影响
- **运维提醒**: 本修改单实施（固件元数据升级）后, LGC 中 202-208 的显示将从"正常"变为
  "Unknown"（见 4.1 节）——属预期变化而非固件回退, 请提前告知 LGC 使用方;
  若 LGC 需恢复完整显示, 需 LGC 侧同步合入等价的占用保护逻辑

---

*QGC 项目提出, 2026-09-09。修改落地后请同步更新 `qgc_integration/03_interfaces.md`(如涉及)与本文档状态。*
