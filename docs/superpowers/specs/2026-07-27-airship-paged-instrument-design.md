# 飞艇专用分页仪表盘设计

> **对标 LGroundControl V1.0.0 仪表盘功能**，为灵云01号飞艇 QGC 提供 LGC 同等的多分页数据仪表盘能力。

- **方案**: A（飞艇专用分页容器，不改 QGC 核心）
- **创建日期**: 2026-07-27
- **维护者**: Lingyun Realm Aviation
- **前置**: 第一轮飞艇 QGC 二次开发已完成（commit `49f73918b`）

---

## 一、背景与目标

### 1.1 背景

第一轮飞艇 QGC 二次开发已完成飞艇类型识别、飞行模式映射、4 个调参页面、浮力 HUD、预飞检查清单、MockLink、`AirshipBallastFactGroup` 注册等。本轮对标 `docs/lingyun/参考/LGroundControl-V1.0.0-用户手册.pdf`（LGC，基于 ArduPilot）的仪表盘功能，在地面站 UI 层面对标。

**对标前提**：LGC 基于 ArduPilot + 多旋翼/固定翼；灵云飞艇基于 PX4 + 飞艇机型。对标聚焦"地面站功能层面"，固件相关功能不照搬。

### 1.2 目标

补齐 LGC 仪表盘相对标准 QGC 的 4 项差距：
1. **分页**（核心差距）：QGC 数据仪表盘是单网格，LGC 支持多分页
2. **飞艇默认指标集**：QGC 为通用默认，需为飞艇预设合适指标
3. **长按姿态球显隐三处数据面板**：QGC 无此交互
4. **姿态球航向指示器**：经核实 QGC 已全部支持，本项无开发工作

---

## 二、现状分析

### 2.1 QGC 现有仪表盘架构

```text
FlyViewBottomRightRowLayout.qml（右下角行布局）
├── TelemetryValuesBar（数据仪表盘容器）
│   └── HorizontalFactValueGrid（行列网格 + 增删行列 + 编辑对话框）
└── FlyViewInstrumentPanel（姿态球面板）
    └── SelectableControl → instrumentQmlFile2 设置 → IntegratedCompassAttitude.qml（姿态球+指南针）
```

### 2.2 QGC 已具备的自定义能力（`InstrumentValueEditDialog`）

| 能力 | QGC 现状 |
|---|---|
| 增删行列 | ✅ `HorizontalFactValueGrid` 已有 +/- 按钮 |
| 自定义指标 | ✅ FactGroup + FactValue 选择 |
| 图标/文字样式 | ✅ Icon / Text 切换 + 图标库 |
| 字体尺寸 | ✅ Size 选择 |
| 显示单位 | ✅ Show Units 开关 |
| 数值区间配色 | ✅ ColorRange |
| 数值区间透明度 | ✅ OpacityRange |
| 数值区间图标切换 | ✅ IconSelectRange |

### 2.3 LGC 真实差距

| LGC 功能 | QGC 现状 | 差距 |
|---|---|---|
| 分页 | ❌ 单网格 | **核心差距** |
| 长按姿态球显隐三处面板 | ❌ | 交互差距 |
| 飞艇默认指标集 | ❌ 通用默认 | 飞艇特有 |
| 姿态球机头锁定 | ✅ `lockNoseUpCompass` | 无 |
| 姿态球家方向"L" | ✅ `headingToHome` | 无 |
| 姿态球下个航点虚线 | ✅ `headingToNextWP` | 无 |
| 姿态球移动方向 COG | ✅ `courseOverGround` | 无 |

> 姿态球四项航向指示器 QGC 已全部实现，受 `showAdditionalIndicatorsCompass` 设置控制，本轮仅需确保飞艇启用。

---

## 三、方案选择

### 方案 A：飞艇专用分页容器（已选定 ✅）

新建飞艇专用分页容器，不改 QGC 核心 `QmlControls`，复用 `HorizontalFactValueGrid` 全部自定义能力。

### 方案 B：扩展 QGC 核心支持多页（未选）

改 `HorizontalFactValueGrid.qml` + `InstrumentValueData` C++ 原生支持 pages 数组。通用但改动大、测试面广，可能触及分系统边界。

### 方案 C：仅默认指标集 + 姿态球增强（未选）

不满足 LGC 分页对标，留缺口。

**选 A 理由**：精准补齐核心差距，复用 QGC 现有自定义能力，与第一轮 `AirshipBallastHUD` 注入模式一致，风险可控、快速见效，不触碰 QGC 核心通用组件。

---

## 四、设计详情

### 4.1 整体架构

```text
FlyViewBottomRightRowLayout.qml（修改：飞艇条件分支）
├── [飞艇] AirshipPagedValuesBar      ← 新建，替代 TelemetryValuesBar
│   └── QGCSwipeView
│       └── Repeater<页> → TelemetryValuesBar(含 HorizontalFactValueGrid)  ← 复用，每页独立 settingsGroup
│   + QGCPageIndicator（页码点）
│   + 编辑模式分页按钮（+页/-页）
└── FlyViewInstrumentPanel（姿态球，不变）
```

- 飞艇判断：`vehicle.vehicleType === MAV_TYPE_AIRSHIP`，与 `AirshipBallastHUD` 同模式
- 非飞艇：原 `TelemetryValuesBar` 行为完全不变
- 复用 `HorizontalFactValueGrid` 全部自定义能力（图标/文字/尺寸/区间配色），零重复造轮

### 4.2 组件结构

**新增文件**（全部在 `src/FlyView/`，飞艇专属）：

| 文件 | 职责 |
|---|---|
| `src/FlyView/AirshipPagedValuesBar.qml` | 分页容器：QGCSwipeView + PageIndicator + 分页增删按钮 |
| `src/FlyView/AirshipInstrumentDefaults.json` | 飞艇默认指标集（每页指标布局） |
| `src/FlyView/AirshipInstrumentDefaultsLoader.h/.cc` | C++ 加载器：首次使用注入默认指标到 settingsGroup |

**修改文件**（与第一轮同模式）：

| 文件 | 修改内容 |
|---|---|
| `src/FlyView/FlyViewBottomRightRowLayout.qml` | 飞艇条件分支加载 `AirshipPagedValuesBar` |
| `src/FlyView/FlyViewInstrumentPanel.qml` | 外层加 `QGCMouseArea` 的 `onPressAndHold` 弹出显隐面板 |
| `src/Settings/FlyViewSettings.h/.cc` + `FlyView.SettingsGroup.json` | 新增 `airshipInstrumentPageCount`、`airshipShowTelemetryBar` 设置项 |
| `src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.cc` | 飞艇默认启用 `showAdditionalIndicatorsCompass` |
| `src/FlyView/CMakeLists.txt` | 注册新 QML/C++ 源文件 |

**不改**：`HorizontalFactValueGrid.qml`、`InstrumentValueEditDialog.qml`、`InstrumentValueData` C++ 核心。

### 4.3 数据流与持久化

- **每页持久化**：每个 `HorizontalFactValueGrid` 用独立 `settingsGroup`（`AirshipInstr.Page0`、`Page1`、`Page2`…），布局自动存盘（QGC 现有机制）
- **页数持久化**：新增 `airshipInstrumentPageCount` 设置项（`FlyViewSettings`），存当前页数
- **页内编辑**：复用原 `settingsUnlocked` + 右键/长按进入编辑；编辑模式下显示 +页/−页/+列/−列/+行/−行
- **默认指标注入**：飞艇首次使用（settingsGroup 为空）时由 `AirshipInstrumentDefaultsLoader` 从 `AirshipInstrumentDefaults.json` 加载飞艇默认指标集到对应 settingsGroup
- **数据来源**：指标走 FactGroup（`vehicle.factGroups`），飞艇的 `AirshipBallastFactGroup`（第一轮已注册）可直接选用

### 4.4 飞艇默认指标集（3 页）

首次使用注入 `AirshipInstrumentDefaults.json`：

| 页 | 定位 | 指标（图标样式 + 数值区间配色） |
|---|---|---|
| 第 1 页 | 飞行核心 | 相对高度、爬升率、地速、航向、距离家、飞行时间 |
| 第 2 页 | 浮力/姿态 | 净浮力(netBuoyancy)、高度误差(altitudeError)、横滚(roll)、俯仰(pitch)、左鼓风机(blowerLeft)、右鼓风机(blowerRight) |
| 第 3 页 | 能源/任务 | 电池剩余、里程(flightDistance)、油门(throttle)、空速(airSpeed，飞艇配 I2C 空速传感器时由 PX4 上报) |

- 数值区间配色：净浮力正值绿/负值红；高度误差超 ±2m 变黄；电池 <20% 变红
- 默认图标走 `InstrumentValueIcons` 现有图标库，不新增
- 指标名须与 `AirshipBallastFactGroup` 实际 fact 对齐（`netBuoyancy`/`blowerLeft`/`blowerRight`/`valveLeft`/`valveRight`/`altitudeError`）

### 4.5 姿态球航向指示器（无开发）

`QGCCompassWidget` 已全部实现 LGC 功能：
- 机头锁定 → `lockNoseUpCompass` 设置
- 家的方向"L" → `headingToHome`
- 下个航点虚线 → `headingToNextWP`（compassDottedLine.svg）
- 移动方向 COG → `courseOverGround`（cOGPointer.svg）

**动作**：仅通过 `AirshipFirmwarePlugin` 默认开启 `showAdditionalIndicatorsCompass`。无新代码。

### 4.6 长按姿态球显隐三处面板

长按 `FlyViewInstrumentPanel`（姿态球）弹出显隐开关面板，控制：
1. 数据仪表盘（`AirshipPagedValuesBar`）显隐 → 新增 `airshipShowTelemetryBar` 设置
2. 地图载具旁飞行数据显隐 → 复用现有地图值显示开关
3. 多飞行器面板显隐 → 复用现有 `enableMultiVehiclePanel`

- 长按手势：在 `FlyViewInstrumentPanel` 外层加 `QGCMouseArea` 的 `onPressAndHold`
- 弹窗以 `Component` + `QGCPopupDialogFactory` **内联**到 `FlyViewInstrumentPanel.qml`，不单独建文件

### 4.7 错误处理

- 页数约束：最小 1 页、最大 5 页；删除末页且仅剩 1 页时禁用"−页"按钮
- 删页确认：`GuidedActionConfirm` 风格二次确认，防误删
- settingsGroup 缺失/损坏 → 回退到 `AirshipInstrumentDefaults.json` 默认页
- 飞艇断连 → 指标显示 `--`（复用 QGC 现有无 vehicle 行为）
- 非飞艇机型 → 完全走原 `TelemetryValuesBar` 路径，零影响

### 4.8 测试策略

| 类别 | 内容 |
|---|---|
| QML 单元测试 | `AirshipPagedValuesBar` 增删页、SwipeView 切换、页内增删行列、settingsGroup 持久化往返 |
| 默认指标注入 | 首次使用加载 JSON，指标名与 `AirshipBallastFactGroup` fact 对齐 |
| MockLink 飞艇 | `PX4MockLinkAirship.params` 场景下端到端验证 3 页指标更新 |
| 回归 | 现有 `Vehicle`/`Firmware`/`QmlQuickTests` 不回归（非飞艇走原路径） |
| 姿态球 | 验证 `showAdditionalIndicatorsCompass` 开启后家/航点/COG 三指示器显示 |

---

## 五、文件清单

### 新增（4 类）
1. `src/FlyView/AirshipPagedValuesBar.qml` — 分页容器
2. `src/FlyView/AirshipInstrumentDefaults.json` — 默认指标集
3. `src/FlyView/AirshipInstrumentDefaultsLoader.h/.cc` — 默认指标加载器
4. 测试：`test/qgc/.../AirshipPagedValuesBarTest.qml` 等

> 显隐开关弹窗不单独建文件，以 `Component` + `QGCPopupDialogFactory` 内联到 `FlyViewInstrumentPanel.qml`（见 4.6）。

### 修改（5 类，均与第一轮同模式）
1. `src/FlyView/FlyViewBottomRightRowLayout.qml` — 飞艇条件分支
2. `src/FlyView/FlyViewInstrumentPanel.qml` — 长按手势
3. `src/Settings/FlyViewSettings.h/.cc` + `FlyView.SettingsGroup.json` — 新增 2 设置项
4. `src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.cc` — 默认启用航向指示器
5. `src/FlyView/CMakeLists.txt` — 注册新文件

### 不改
- `src/QmlControls/HorizontalFactValueGrid.qml`
- `src/QmlControls/InstrumentValueEditDialog.qml`
- `InstrumentValueData` C++ 核心

---

## 六、风险与边界

- **工作边界**：遵循工作区规则"不做 projects 文件夹内分系统代码修改"。本设计全部新增/修改集中在 `src/FlyView/`、`src/Settings/`、`src/FirmwarePlugin/PX4/`，与第一轮同模式，不触碰 `src/QmlControls/` 核心。
- **回归风险**：非飞艇机型走原 `TelemetryValuesBar` 路径，零影响。需回归测试验证。
- **持久化兼容**：新增 settingsGroup 不与现有冲突（`AirshipInstr.Page*` 命名空间独立）。
- **飞艇 MockLink**：依赖第一轮 `PX4MockLinkAirship.params`，需验证 `AirshipBallastFactGroup` 的 NAMED_VALUE_FLOAT 在 MockLink 下正常发送。

---

## 七、后续

设计批准后转交 writing-plans 制定分阶段实现计划。
