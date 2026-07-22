# QGroundControl 架构详解

> 本文档面向**需要深入理解并修改 QGC 源码**的开发者，结合 [`AGENTS.md`](file:///home/hex/qgroundcontrol/AGENTS.md)、[`CODING_STYLE.md`](file:///home/hex/qgroundcontrol/CODING_STYLE.md)、[`.github/CONTRIBUTING.md`](file:///home/hex/qgroundcontrol/.github/CONTRIBUTING.md) 三份上游规范，对项目做系统化拆解。
>
> 适用读者：正在做二次开发（如 PX4 飞艇适配）、自定义机型 fork、性能调优或 AI 辅助编程的工程师。

---

## 目录

1. [项目定位](#1-项目定位)
2. [技术栈与构建系统](#2-技术栈与构建系统)
3. [顶层目录结构](#3-顶层目录结构)
4. [核心架构模式（"黄金规则"）](#4-核心架构模式黄金规则)
5. [启动流程与运行时骨架](#5-启动流程与运行时骨架)
6. [MAVLink 与通信层](#6-mavlink-与通信层)
7. [飞控模型：Vehicle](#7-飞控模型vehicle)
8. [Fact System：参数体系](#8-fact-system参数体系)
9. [Firmware Plugin：固件抽象](#9-firmware-plugin固件抽象)
10. [QML / UI 架构](#10-qml--ui-架构)
11. [子系统一览](#11-子系统一览)
12. [测试体系](#12-测试体系)
13. [CI/CD 与发布](#13-cicd-与发布)
14. [开发工具链](#14-开发工具链)
15. [适配自定义固件 / 机型的路径](#15-适配自定义固件--机型的路径)
16. [常见陷阱与最佳实践](#16-常见陷阱与最佳实践)

---

## 1. 项目定位

**QGroundControl (QGC)** 是 Dronecode 基金会下 MAVLink 生态的官方跨平台地面控制站，托管在 <https://github.com/mavlink/qgroundcontrol>。

- **形态**：桌面（Windows / macOS / Linux）+ 移动（Android / iOS）的 Qt Quick 应用
- **协议层**：MAVLink 2（同时支持 1）
- **目标固件**：PX4、ArduPilot（含 Copter / Plane / Rover / Sub）
- **协议开源**：Apache 2.0 + GPL v3 双协议（[`.github/COPYING.md`](file:///home/hex/qgroundcontrol/.github/COPYING.md)）
- **核心能力**：实时遥测显示、任务规划、参数配置、传感器校准、固件烧录、日志分析、视频流、FollowMe、3D Viewer、ADSB 交通态势

它**不是一个普通 Qt Widgets 桌面程序**——它的设计哲学是：

> **飞控的差异被封装在 `FirmwarePlugin`，UI 与业务模型永远只看到"通用飞行器"接口。**
> 整个 QGC 主体代码（除 `FirmwarePlugin/PX4` 与 `FirmwarePlugin/APM`）不应当出现任何 PX4/ArduPilot 专属分支。

---

## 2. 技术栈与构建系统

| 维度 | 选型 | 备注 |
|------|------|------|
| C++ 标准 | **C++20** | 启用 `[[nodiscard]]`、`std::span`、`std::string_view`、ranges、designated initializers |
| GUI 框架 | **Qt 6.10+** Quick / QML + Quick Controls 2 | 还用 Quick3D（Viewer3D）、Location（地图）、Multimedia（视频）、HttpServer（部分本地 API） |
| 构建 | **CMake ≥ 3.25** + Ninja | 预设见 [`cmake/presets/`](file:///home/hex/qgroundcontrol/cmake/presets/) |
| 依赖管理 | **CPM.cmake**（[cmake/modules/CPM.cmake](file:///home/hex/qgroundcontrol/cmake/modules/CPM.cmake)） | 通过 FetchContent 拉第三方 |
| 任务运行 | **just** ≥ 1.30（rust-just，apt 自带的 1.21 太老） | 见 [`justfile`](file:///home/hex/qgroundcontrol/justfile) |
| 静态分析 | clang-format / clang-tidy / clazy / cppcheck / qmllint | 集成到 pre-commit |
| 测试 | Qt Test + CTest | 标签 `Unit` / `Integration` / `Flaky` / `Network` |
| 翻译 | Qt Linguist + Crowdin | `translations/qgc_*.ts` |
| 平台 | Windows / macOS / Linux / Android / iOS | 见 [`.github/workflows/`](file:///home/hex/qgroundcontrol/.github/workflows/) |

**入口**：[`src/main.cc`](file:///home/hex/qgroundcontrol/src/main.cc) → [`QGCApplication`](file:///home/hex/qgroundcontrol/src/QGCApplication.h) → QML 引擎 → `app.exec()`。

**关键文件**：
- [`CMakeLists.txt`](file:///home/hex/qgroundcontrol/CMakeLists.txt)：Qt6 / CPM / 平台 / QML 模块 / 翻译总入口
- [`src/CMakeLists.txt`](file:///home/hex/qgroundcontrol/src/CMakeLists.txt)：按子系统 `add_subdirectory` 组合
- [`.github/build-config.json`](file:///home/hex/qgroundcontrol/.github/build-config.json)：统一版本号
- [`justfile`](file:///home/hex/qgroundcontrol/justfile)：开发任务统一入口

---

## 3. 顶层目录结构

```text
qgroundcontrol/
├── src/                    # 应用代码（C++ + QML）
├── test/                   # 单元测试（镜像 src/ 结构）
├── tools/                  # 本地开发脚本（Python + just）
├── resources/              # 图标、音频、QtQuickControls 主题
├── translations/           # 30+ 语言 .ts 文件
├── deploy/                 # Docker / iOS / Linux AppImage / Vagrant
├── docs/                   # VitePress 文档站（多语言）
├── cmake/                  # 自定义 CMake 模块 + CPM + 平台预设
├── android/                # Android 平台配置
├── custom-example/         # 产品化 fork 模板
├── .github/                # CI / workflows / actions / 脚本
├── justfile
├── CMakeLists.txt          # 顶层 CMake
└── AGENTS.md, CODING_STYLE.md, README.md
```

### 3.1 `src/` 子系统一览

| 子系统 | 路径 | 作用 |
|--------|------|------|
| 入口 / 应用对象 | `src/main.cc`、`src/QGCApplication.{h,cc}` | 启动、命令行、翻译、QML 引擎、消息中心 |
| 参数系统 | `src/FactSystem/` | 强类型参数 + 元数据 |
| 飞控模型 | `src/Vehicle/` | 飞行器状态、命令、组件 |
| 固件抽象 | `src/FirmwarePlugin/{PX4,APM,Generic}/` | 固件差异封装 |
| 飞控配置 UI | `src/AutoPilotPlugins/{PX4,APM,Common}/` | Setup 页 |
| 任务规划 | `src/MissionManager/`、`src/PlanView/` | 任务、围栏、安全点 |
| MAVLink | `src/MAVLink/` | 协议、FTP 客户端、消息流控 |
| 通信链路 | `src/Comms/` | Serial/UDP/TCP/Mock/LogReplay |
| 设置 | `src/Settings/` | QSettings 抽象分组 |
| 飞行视图 | `src/FlyView/` | HUD、工具条、视频、PIP |
| 工具栏 | `src/Toolbar/` | 顶部状态指示器 |
| 地图 | `src/FlightMap/`、`src/QtLocationPlugin/` | 地图、瓦片、Terrain |
| 视频 | `src/VideoManager/` | GStreamer/FFmpeg 解码 |
| 其它 | `ADSB/`、`Gimbal/`、`GPS/`、`Camera/`、`FollowMe/`、`Terrain/`、`Viewer3D/`、`Joystick/` | 扩展能力 |

### 3.2 关键关系图

```text
                ┌────────────────────────────────────────┐
                │            QGCApplication              │
                │  （全局应用、QML 引擎、消息中心）        │
                └─────────────┬──────────────────────────┘
                              │
        ┌─────────────────────┼────────────────────────┐
        │                     │                        │
┌───────▼────────┐    ┌───────▼─────────┐    ┌────────▼────────┐
│  LinkManager   │    │   VehicleMgr    │    │   SettingsMgr   │
│ (多链路并发)    │    │  (多飞行器并发)   │    │  (QSettings 抽象)│
└───────┬────────┘    └───────┬─────────┘    └─────────────────┘
        │                     │
        │            ┌────────▼────────┐
        │            │     Vehicle     │  ←── FactGroup（参数容器）
        │            └────────┬────────┘
        │                     │
        │            ┌────────▼────────┐
        │            │ FirmwarePlugin  │  ←─ PX4 / APM / Generic
        │            └────────┬────────┘
        │                     │
        │                     ├─ ParameterManager
        │                     ├─ MissionManager
        │                     ├─ GeoFenceManager
        │                     ├─ FTPManager
        │                     └─ ...
        │                     │
┌───────▼────────┐    ┌───────▼─────────┐
│  MAVLinkProtocol│   │  AutoPilotPlugin│
│  + 各 Link      │   │  + VehicleComponents
└────────────────┘   └─────────────────┘
                              │
                              ▼
                         QML 视图层
         （FlyView / PlanView / SetupView / SettingsView）
```

---

## 4. 核心架构模式（"黄金规则"）

[`AGENTS.md`](file:///home/hex/qgroundcontrol/AGENTS.md) 强调 4 条必须遵守的架构模式。这些是 QGC 多年沉淀的"约束设计"，违反任一条都会让 PR 难以通过机器评审。

### 4.1 Fact System —— 一切"参数/值"都用 Fact

- 唯一类型：[**`src/FactSystem/Fact.h`**](file:///home/hex/qgroundcontrol/src/FactSystem/Fact.h) / `FactGroup` / `FactMetaData` / `SettingsFact`
- **任何**飞控参数、UI 控件值、设置项都**必须**用 Fact + 元数据
- 优势：单位转换、范围校验、枚举翻译、UI 自动生成、QML 双向绑定
- 禁止：自定义 `Q_PROPERTY` 存"小数值"、绕过 `Fact` 的私有存储

### 4.2 Multi-Vehicle —— 必须 null-check `activeVehicle()`

- 入口：[`src/Vehicle/VehicleManager`](file:///home/hex/qgroundcontrol/src/Vehicle/)（管理多 Vehicle）
- 规则：**任何**对 `activeVehicle()` / `firstActiveVehicle()` 的使用都必须先 `if (vehicle)` 判空
- 由 pre-commit 钩子 `vehicle-null-check` 静态检查
- 行为：当没有连接或连接断开时返回 `nullptr`，大量代码因此必须用防御式写法

### 4.3 FirmwarePlugin —— 固件差异集中点

- 基类：[`src/FirmwarePlugin/FirmwarePlugin.h`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/FirmwarePlugin.h)
- 派生：[`PX4FirmwarePlugin`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/PX4FirmwarePlugin.h)、[`APMFirmwarePlugin`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/APM/APMFirmwarePlugin.h) 及更细分的 `ArduCopter/Plane/Rover/SubFirmwarePlugin`
- 封装内容：飞行模式映射、能力位、命令转换、参数重命名表、地面站特性支持度
- 关键能力位 `FirmwareCapabilities`、参数重命名 `remapParamNameMajorVersionMap_t`
- 规则：**严禁**在 `src/Vehicle/`、`src/MissionManager/` 等通用模块出现 `#ifdef PX4` 或写死 PX4 字符串

### 4.4 QML 集成 —— 显式声明元类型

- 必须用 `Q_OBJECT` + `QML_ELEMENT` / `QML_UNCREATABLE` / `QML_SINGLETON`
- 暴露属性 `Q_PROPERTY(...)` + `NOTIFY` 信号
- C++ 端只读数据：QML 用 `Q_PROPERTY(... READ ... CONSTANT)`；可变数据：必须带 NOTIFY
- 业务枚举暴露给 QML：`Q_ENUM(...)` 或 `Q_ENUM_NS(...)`
- pre-commit 钩子 `qmllint` 会扫 QML 文件

---

## 5. 启动流程与运行时骨架

### 5.1 启动序列（[`src/main.cc`](file:///home/hex/qgroundcontrol/src/main.cc)）

```text
main()
  ├── QGCCommandLineParser::parse(argc, argv)         // 命令行
  ├── Platform::initialize(...)                       // 平台特定初始化（GL、视频后端等）
  ├── QGCApplication app(argc, argv, args)
  ├── LogManager::installHandler()                    // 日志拦截
  ├── Platform::setupPostApp()                        // 平台后置
  ├── app.init()                                      // QML 引擎、ImageProvider、参数元数据缓存
  ├── LogManager::applyEnvironmentLogLevel()          // QGC_LOG_LEVEL
  └── QGCCommandLineParser::determineAppMode(args) ──► AppMode
        ├── Gui          → app.exec()
        ├── BootTest     → 简单启动检查（GStreamer/GL）
        ├── ListTests    → 列出单元测试
        └── Test         → 进入 QGCUnitTest 框架
```

### 5.2 应用对象

[`QGCApplication`](file:///home/hex/qgroundcontrol/src/QGCApplication.h) 继承 `QGuiApplication`，负责：

- 加载主 QML（`MainWindow/MainWindow.qml`）
- 注册 `QGCImageProvider`（把车辆图标等异步注入给 QML）
- 维护翻译（`QTranslator` × 2：源码翻译 + Qt 库翻译）
- 全局消息（`showAppMessage` / `showCriticalVehicleMessage` / `showRebootAppMessage`）
- "信号压缩"：相同 meta-method 的多次 post event 只保留最后一次，节流 UI 更新
- 设置升级、版本检查、missing parameter 告警

### 5.3 平台层

- [`src/Android/`](file:///home/hex/qgroundcontrol/src/Android/)：Android 事件、串口
- [`deploy/`](file:///home/hex/qgroundcontrol/deploy/)：iOS Info.plist、Linux AppImage、Windows ICO
- 平台特定 CMake 入口在 [`cmake/platform/`](file:///home/hex/qgroundcontrol/cmake/platform/)

---

## 6. MAVLink 与通信层

### 6.1 链路层（[`src/Comms/`](file:///home/hex/qgroundcontrol/src/Comms/)）

| 类型 | 类 | 用途 |
|------|----|------|
| Serial | [`SerialLink`](file:///home/hex/qgroundcontrol/src/Comms/SerialLink.h) | 真实硬件 / USB 串口 |
| UDP | [`UDPLink`](file:///home/hex/qgroundcontrol/src/Comms/UDPLink.h) | 数传、SITL 仿真最常用 |
| TCP | [`TCPLink`](file:///home/hex/qgroundcontrol/src/Comms/TCPLink.h) | 远程 GCS 桥接 |
| Log Replay | [`LogReplayLink`](file:///home/hex/qgroundcontrol/src/Comms/LogReplayLink.h) | 重放 `.tlog` 文件 |
| Mock | [`MockLink`](file:///home/hex/qgroundcontrol/src/Comms/MockLink/MockLink.h) | 无飞控开发/测试 |

- 链路由 [`LinkManager`](file:///home/hex/qgroundcontrol/src/Comms/LinkManager.h) 单例管理
- 配置由 [`LinkConfiguration`](file:///home/hex/qgroundcontrol/src/Comms/LinkConfiguration.h) 体系持久化
- 每条链路有独立 `LinkInterface`，多链路可同时存在

### 6.2 协议层（[`src/MAVLink/`](file:///home/hex/qgroundcontrol/src/MAVLink/)）

- [`MAVLinkProtocol`](file:///home/hex/qgroundcontrol/src/Comms/MAVLinkProtocol.h)：MAVLink 帧解析、心跳、丢包统计、版本协商
- [`MAVLinkFTP`](file:///home/hex/qgroundcontrol/src/MAVLink/MAVLinkFTP.h)：在飞控上读文件（参数、日志、任务）
- [`QGCMAVLink`](file:///home/hex/qgroundcontrol/src/MAVLink/QGCMAVLink.h)：MAV_TYPE ↔ VehicleClass 映射、自定义枚举、消息常量
- 关键枚举：`MAV_TYPE_AIRSHIP` → `VehicleClassAirship`（已识别）、`MAV_TYPE_QUADROTOR` → `VehicleClassMultiRotor` 等

### 6.3 消息流控

- [`RequestMessageCoordinator`](file:///home/hex/qgroundcontrol/src/Vehicle/)：统一请求/响应
- [`MessageIntervalManager`](file:///home/hex/qgroundcontrol/src/Vehicle/)：按需调整消息发送频率
- [`MavCommandQueue`](file:///home/hex/qgroundcontrol/src/Vehicle/MavCommandQueue.h)：命令队列与 ACK 处理

---

## 7. 飞控模型：Vehicle

[`src/Vehicle/Vehicle.h`](file:///home/hex/qgroundcontrol/src/Vehicle/Vehicle.h) 是 QGC 中最庞大的类（约 3000+ 行），代表**一架飞行器**。

### 7.1 继承关系

```text
QObject
  └── VehicleFactGroup : VehicleTypes
        └── Vehicle
```

`VehicleFactGroup` 把"飞行器拥有的所有 Fact"聚合成一个树，便于一次性绑定到 QML。

### 7.2 Vehicle 的"组合件"

构造时，`Vehicle` 持有一组子管理器，几乎每个都对应 QGC 的一个能力：

| 子对象 | 作用 |
|--------|------|
| `ParameterManager` | MAVLink PARAM_PROTOCOL 协议，参数读写、remap |
| `MissionManager` | 航点任务上传/下载 |
| `GeoFenceManager` | 地理围栏 |
| `RallyPointManager` | 安全点（RTL 备降点） |
| `MAVLinkLogManager` | 飞控日志下载 |
| `FTPManager` | MAVLink FTP |
| `ComponentInformationManager` | 组件信息 |
| `StatusTextHandler` | 状态文本消息 |
| `GimbalController` | 云台控制 |
| `QGCCameraManager` | 相机控制 |
| `RemoteIDManager` | 远程 ID |
| `Autotune` | 自动调参 |
| `VehicleObjectAvoidance` | 避障 |
| `MavCommandQueue` | 命令队列 |
| `TrajectoryPoints` | 轨迹回放 |

### 7.3 Vehicle 的关键属性

参见 [Vehicle.h:144-271](file:///home/hex/qgroundcontrol/src/Vehicle/Vehicle.h#L144-L271)：

- **类型识别**：`airship` / `fixedWing` / `multiRotor` / `vtol` / `rover` / `sub` / `spacecraft` / `generic`（Q_PROPERTY）
- **状态**：`armed`、`flying`、`landing`、`inFwdFlight`、`vtolInFwdFlight`
- **飞行模式**：`flightMode` / `flightModes`（由 FirmwarePlugin 提供列表）
- **位置**：`coordinate` / `homePosition` / `armedPosition`
- **遥测 FactGroup**：`vehicle`、`gps`、`batteries`、`escs`、`wind`、`vibration`、`temperature`、`distanceSensors`、`actuators`、`localPosition`、`setpoint` …

### 7.4 关键约定

- **多机**：所有 QML 端**只能**通过 `activeVehicle` 访问，不要保留 Vehicle 指针
- **首连状态机**：第一次连接时 `InitialConnectStateMachine` 会先握手参数/任务/围栏/日志/位置等，再发出 `initialConnectComplete`
- **OFFLINE 飞行器**：用于"无连接时编辑任务/参数"，构造函数 `Vehicle(MAV_AUTOPILOT, MAV_TYPE, QObject*)` 是离线模式

---

## 8. Fact System：参数体系

[`src/FactSystem/`](file:///home/hex/qgroundcontrol/src/FactSystem/) 是 QGC 最有特色的一层。

### 8.1 三件套

| 类 | 作用 |
|----|------|
| [`Fact`](file:///home/hex/qgroundcontrol/src/FactSystem/Fact.h) | 单个值对象，强类型 + 元数据驱动 |
| [`FactGroup`](file:///home/hex/qgroundcontrol/src/FactSystem/FactGroup.h) | 一组 Fact 聚合（嵌套），同时也是 QML 端 `vehicle.gps.alt` 这种路径的基础 |
| [`FactMetaData`](file:///home/hex/qgroundcontrol/src/FactSystem/FactMetaData.h) | 元数据：单位、范围、枚举、默认值、short/long description、reboot 标志等 |

### 8.2 Fact 的状态机

- `_rawValue` ↔ `_cookedValue`：raw 是飞控来的原始量，cooked 是 UI 显示用（可带单位换算）
- 写流程：`setCookedValue()` → 单位/范围校验 → `containerRawValueChanged` → 飞控 ACK 后 `_containerRawValueChanged` → 触发 valueChanged 信号
- 写后回包路径：`containerSetRawValue()`（来自 `ParameterManager`）
- 性能优化：`setSendValueChangedSignals(false)` 期间信号延迟，UI 节流

### 8.3 Fact 在 QML 的用法

```qml
TextField {
    text: vehicle.gps.alt.cookedValueString
    onEditingFinished: vehicle.gps.alt.cookedValue = text
}
```

`vehicle.gps.alt` 这种属性访问是 `Q_PROPERTY(FactGroup* ...)` + `FactGroup::getFact()` 实现的，路径解析来自 Fact 注册时填的"name"。

### 8.4 FactMetaData 来源

- **飞控参数**：[`src/FirmwarePlugin/PX4/PX4ParameterFactMetaData.json`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/PX4ParameterFactMetaData.json) 等（运行时下载并缓存）
- **设置项**：[`src/Settings/*.json`](file:///home/hex/qgroundcontrol/src/Settings/)，`SettingsFact` 直接吃元数据 JSON
- **任务项**：[`src/FirmwarePlugin/PX4/PX4-MavCmdInfo*.json`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/) 等

---

## 9. Firmware Plugin：固件抽象

[`src/FirmwarePlugin/`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/) 是 QGC 唯一允许出现"PX4 / APM 字面量"的地方。

### 9.1 工厂模式

```text
FirmwarePluginFactory
  ├── PX4FirmwarePluginFactory      → 派发 PX4
  │     └── PX4FirmwarePlugin
  ├── APMFirmwarePluginFactory
  │     ├── ArduCopterFirmwarePlugin
  │     ├── ArduPlaneFirmwarePlugin
  │     ├── ArduRoverFirmwarePlugin
  │     └── ArduSubFirmwarePlugin
  └── GenericFirmwarePluginFactory
        └── GenericFirmwarePlugin
```

[`FirmwarePluginManager`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/FirmwarePluginManager.h) 根据 MAV_AUTOPILOT 选择工厂。

### 9.2 必须实现的方法（按需 override）

参见 [`FirmwarePlugin.h`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/FirmwarePlugin.h)：

- `supportedMissionCommands(vehicleClass)` → 任务编辑器可用的 MAV_CMD
- `missionCommandOverrides(vehicleClass)` → MAV_CMD JSON 描述文件路径
- `setFlightMode`、`pauseVehicle`、`guidedModeRTL/Land/Takeoff/Goto`
- `isCapable(capability)` 能力位
- `multiRotorCoaxialMotors` / `multiRotorXConfig` / `motorCount`
- `setGuidedMode` / `takeoff`
- `remapParamNameMajorVersionMap_t` 参数重命名表

### 9.3 当前对飞艇的支持现状

- **已支持**：`MAV_TYPE_AIRSHIP` → `VehicleClassAirship` 映射（[`QGCMAVLink.cc:220`](file:///home/hex/qgroundcontrol/src/MAVLink/QGCMAVLink.cc#L220)）、`Vehicle::airship()` Q_PROPERTY
- **缺失**：
  - `PX4FirmwarePlugin::missionCommandOverrides` 没有 `VehicleClassAirship` 分支（[PX4FirmwarePlugin.cc:232](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/PX4FirmwarePlugin.cc#L232)）
  - 没有 `PX4-MavCmdInfoAirship.json`
  - 没有 `PX4TuningComponentAirship*.qml`
  - 飞行模式表未覆盖 PX4 飞艇的自定义模式

详见 §15 适配路径。

---

## 10. QML / UI 架构

### 10.1 视图层级

```text
MainWindow.qml
  └── MainWindowSavedState.qml
        ├── SetupView.qml    （Setup 飞控配置）
        ├── PlanView.qml     （任务规划）
        ├── FlyView.qml      （飞行/遥测）
        ├── AnalyzeView.qml  （日志分析）
        ├── Viewer3D.qml     （3D Viewer）
        └── SettingsView.qml （应用设置）
```

### 10.2 视图层

| 视图 | 路径 | 备注 |
|------|------|------|
| Setup | [`src/AutoPilotPlugins/`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/) | PX4 / APM / Common 三大类配置项 |
| Plan | [`src/PlanView/`](file:///home/hex/qgroundcontrol/src/PlanView/) | 航点/围栏/安全点编辑 |
| Fly | [`src/FlyView/`](file:///home/hex/qgroundcontrol/src/FlyView/) | 实时飞行、工具条、HUD、视频 |
| Analyze | [`src/AnalyzeView/`](file:///home/hex/qgroundcontrol/src/AnalyzeView/) | 日志下载、MAVLink 检查、GeoTag |
| Toolbar | [`src/Toolbar/`](file:///home/hex/qgroundcontrol/src/Toolbar/) | 顶部状态指示器 |
| FlightMap | [`src/FlightMap/`](file:///home/hex/qgroundcontrol/src/FlightMap/) | 地图组件 |
| QmlControls | [`src/QmlControls/`](file:///home/hex/qgroundcontrol/src/QmlControls/) | 可复用组件库 |

### 10.3 复用组件（`QmlControls`）

- `QGCButton` / `QGCLabel` / `QGCSlider`（品牌色）
- `FactSlider` / `FactValueGrid`（Fact 自动绑定）
- `QGCPalette`（设计调色板）
- `SetupPage`（配置页通用模板）
- `ToolStrip`（侧边工具条）
- `PipView` / `PipState`（画中画）
- `PIDTuning` / `AutotuneUI`（调参 UI）

### 10.4 多设备 / 多语言

- 自适应移动端：`qgcApp().fakeMobile()` + `MainWindowSavedState.qml`
- 翻译：源码字符串走 `qsTr()`；运行时切换 `QGCApplication::setLanguage()`
- 主题：QtQuickControls2 conf + `QGCPalette`

---

## 11. 子系统一览

按职责分组（每个都是独立 `add_subdirectory`，CMake 隔离）：

### 11.1 飞行与控制

- `Vehicle/`、`MissionManager/`、`AutoPilotPlugins/`、`FollowMe/`、`StandardModes/`

### 11.2 感知与传感

- `GPS/`（含 NTRIP、RTK、RTCM）、`Terrain/`、`Camera/`、`Gimbal/`

### 11.3 通信

- `Comms/`、`MAVLink/`、`Joystick/`、`ADSB/`、`RemoteIDManager`

### 11.4 数据 / 设置

- `FactSystem/`、`Settings/`、`LogManager/`

### 11.5 视图

- `FlyView/`、`PlanView/`、`SetupView/`（在 AutoPilotPlugins）、`AnalyzeView/`、`Toolbar/`、`FlightMap/`、`QmlControls/`、`Viewer3D/`

### 11.6 平台

- `Android/`、`QtLocationPlugin/`、`VideoManager/`

### 11.7 公共基础

- `Utilities/`（`AppMessages`、`Geo`、`Math`）

---

## 12. 测试体系

[`test/TESTING.md`](file:///home/hex/qgroundcontrol/test/TESTING.md) 定义了完整的测试约定。

### 12.1 框架

- **Qt Test** + **CTest**
- 入口宏：在 `QGCApplication` 启动后由 `QGCCommandLineParser` 解析 `--unittest` 进入
- `UnitTestList` 注册所有用例（[test/UnitTestList.cc](file:///home/hex/qgroundcontrol/test/UnitTestList.cc)）

### 12.2 基类

- `UnitTest`：基础
- `VehicleTest`：虚拟 Vehicle 注入
- `MissionTest`：虚拟 Mission 注入
- `MultiSignalSpy`：跨多信号做统一断言（Qt 信号聚合）

### 12.3 CTest 标签

- `Unit` / `Integration` / `Flaky` / `Network`
- 默认 `just test` = `ctest -L "Unit|Integration" -LE "Flaky|Network"`

### 12.4 镜像结构

```text
test/ 镜像 src/
  ├── Vehicle/     （FTPManagerTest 等）
  ├── Comms/
  ├── MAVLink/     （QGCMAVLinkTest）
  ├── GPS/         （GPSDriverTest / GPSRtkTest / NTRIPManagerTest / RTCMParserTest）
  ├── ADSB/        （带 Python simulator）
  ├── Camera/
  ├── FollowMe/
  ├── FactSystem/
  ├── Joystick/    （含 MockJoystick / SDLTest）
  ├── Terrain/
  ├── Utilities/
  ├── Viewer3D/
  └── QmlUITests/
```

### 12.5 工具测试

[`.github/scripts/tests/`](file:///home/hex/qgroundcontrol/.github/scripts/) + [`tools/tests/`](file:///home/hex/qgroundcontrol/tools/tests/)：CI Python 脚本用 pytest 验证（[`.github/ci-overview.md`](file:///home/hex/qgroundcontrol/.github/ci-overview.md)）。

### 12.6 覆盖率

[`tools/coverage.py`](file:///home/hex/qgroundcontrol/tools/coverage.py) + `just coverage` 生成报告；CI 走 [`.github/actions/coverage/`](file:///home/hex/qgroundcontrol/.github/actions/)。

---

## 13. CI/CD 与发布

[`.github/ci-overview.md`](file:///home/hex/qgroundcontrol/.github/ci-overview.md) 是 CI 的事实源。

### 13.1 Workflow 一览

| Workflow | 触发 | 作用 |
|----------|------|------|
| `linux.yml` / `macos.yml` / `windows.yml` | push / PR | 桌面构建 + 测试 |
| `android.yml` / `ios.yml` | push / PR | 移动端构建 |
| `flatpak.yml` | release | Linux Flatpak |
| `pre-commit.yml` | PR | 代码规范 |
| `codeql.yml` | schedule / PR | 安全扫描 |
| `analysis.yml` | 手动 / 定期 | 静态分析（reviewdog） |
| `docs.yml` / `doxygen.yml` | push to master | VitePress 站 + Doxygen API |
| `release.yml` | tag | semantic-release 自动发版（[`.releaserc.json`](file:///home/hex/qgroundcontrol/.releaserc.json)） |
| `lupdate.yml` | push to master | 同步翻译 |
| `docker.yml` | 手动 | Docker 镜像 |
| `pr-checks.yml` / `build-results.yml` | PR | 汇总评论 |
| `dependency-review.yml` / `scorecard.yml` | PR | 依赖与安全 |
| `px4-metadata.yml` | schedule | 同步 PX4 元数据 |
| `welcome.yml` | 新 PR | 欢迎新贡献者 |

### 13.2 共享 actions

[`.github/actions/`](file:///home/hex/qgroundcontrol/.github/actions/)：高度复用
- `cmake-configure/` / `cmake-build/` / `run-unit-tests/`
- `build-setup/` / `install-dependencies/`
- `cache/` / `qt-install/`
- `coverage/` / `test-report/`
- `attest-sbom/` / `attest-and-upload/`
- `aws-upload/` / `deploy-docs/`

### 13.3 版本管理

- 单一来源：[`.github/build-config.json`](file:///home/hex/qgroundcontrol/.github/build-config.json)（Qt 版本、CMake 最低版本、平台 SDK 标识等）
- 应用版本：CMake 通过 `Git.cmake` 在 `qgc_version.h.in` 生成 `QGC_APP_VERSION` 宏
- release 流程：semantic-release 解析 Conventional Commits，发布到 GitHub Release + 二进制 artifact

---

## 14. 开发工具链

[`tools/README.md`](file:///home/hex/qgroundcontrol/tools/README.md) 是事实源，摘要：

| 工具 | 用途 | 入口 |
|------|------|------|
| `analyze.py` | 静态分析 / 格式化 | `just analyze` / `just format` / `just format-fix` |
| `clean.py` | 清理构建产物 | `just clean` |
| `coverage.py` | 覆盖率 | `just coverage` |
| `run_tests.py` | Qt 单元测试运行 | `just test` |
| `pre_commit.py` | pre-commit 钩子 | `just lint` |
| `release.py` | 发布版本 | 内部 |
| `check_deps.py` | 检查依赖版本 | `just check-deps` |
| `configure.py` | CMake 配置 | `just configure` |
| `build_profile.py` | 构建热点 | `python3 tools/build_profile.py -B build` |
| `lsp/` | 自定义 Language Server | 提供 Fact/MAVLink 智能感知 |
| `locators/` | CLI 搜索 Fact/MAVLink | `python3 tools/locators/qgc_locator.py` |
| `setup/` | 装 Qt / Python / 依赖 | `just setup` |
| `simulation/` | SITL 启动脚本 | `tools/simulation/run-px4-sitl.sh` |
| `analyzers/` | 自定义检查器 | clang-format / clang-tidy / clazy / qmllint / vehicle-null-check |
| `log-analyzer/` | 日志分析 | 独立工具 |
| `translations/` | 翻译工具 | Crowdin + lupdate |
| `qtcreator/` | Qt Creator 集成 | 插件/片段 |
| `skills/` | 内部 skill 集合 | `tools/skills/qt-qml/` |

**pre-commit 钩子**（[`.pre-commit-config.yaml`](file:///home/hex/qgroundcontrol/.pre-commit-config.yaml)）：
clang-format、clang-tidy、ruff、pyright、shellcheck、actionlint、zizmor、qmllint、clazy、vehicle-null-check、check-no-qassert。

---

## 15. 适配自定义固件 / 机型的路径

> **以 PX4 飞艇为例**演示完整流程。所有改动都应优先考虑放进 `custom-example/`，避免污染上游。

### 15.1 PX4 端必须先确定（与飞控同学约定）

| 项 | 约定 | QGC 端影响 |
|----|------|----------|
| `MAV_TYPE` | 必须广播 `MAV_TYPE_AIRSHIP` | `Vehicle::airship()` Q_PROPERTY |
| 自定义模式 | `px4_custom_mode.h` 枚举值 | `FirmwarePlugin::setFlightMode` 路由 |
| 新参数 | 命名规范、跨版本重命名 | `FactMetaData` + `remapParamNameMajorVersionMap_t` |
| 关键命令 | 起飞/降落/RTL 命令 MAV_CMD | `supportedMissionCommands` |
| 飞艇特色消息 | 净浮力/囊压等自定义消息 | 扩 `VehicleFactGroup` |

### 15.2 QGC 端改造清单

#### 必做

1. **飞行模式 + 任务项**
   - `PX4FirmwarePlugin::missionCommandOverrides` 新增 `VehicleClassAirship` 分支
   - 新建 [`PX4-MavCmdInfoAirship.json`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/)（参考 `PX4-MavCmdInfoMultiRotor.json`）
   - `PX4FirmwarePlugin::supportedMissionCommands` 加 airship 列表
2. **机架组件**：[`AirframeComponentAirframes.cc`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/PX4/AirframeComponentAirframes.cc) 注册新机架，`AirframeFactMetaData.xml` 加参数
3. **参数元数据**：[`PX4ParameterFactMetaData.json`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/PX4ParameterFactMetaData.json) 加新参数元数据
4. **Setup 组件**：[`PX4AutoPilotPlugin.cc`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/PX4/PX4AutoPilotPlugin.cc) 决定飞艇的 VehicleComponent 列表
5. **Tuning**：[`PX4TuningComponent*.qml`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/PX4/) 派生飞艇版本；Autotune 视情况禁用
6. **FlyView 守卫**：[`FlyViewToolBar.qml`](file:///home/hex/qgroundcontrol/src/FlyView/) + FlyView 中用 `vehicle.airship` 隐藏 Orbit / VTOL / Autotune 按钮

#### 选做

- 飞艇专属 Checklist：[`FlyView/`](file:///home/hex/qgroundcontrol/src/FlyView/) 新建 `AirshipChecklist.qml`
- 飞艇特色遥测：扩 [`VehicleFactGroup.h`](file:///home/hex/qgroundcontrol/src/Vehicle/VehicleFactGroup.h)（仿 `BatteryFactGroup` 写法）
- Joystick 飞艇布局
- 图标替换：[`src/AutoPilotPlugins/Common/Images/Airship.svg`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/Common/Images/Airship.svg) 已有

#### 工具链

- MockLink 加 airship 预设：[`MockLink.cc`](file:///home/hex/qgroundcontrol/src/Comms/MockLink/MockLink.cc)
- SITL 脚本：`tools/simulation/` 加 `run-px4-sitl-airship.sh`
- 单元测试：`test/Airship/` 镜像新增

### 15.3 推荐工作顺序

1. PX4 端 SITL 跑通
2. QGC 加 `VehicleClassAirship` 分支，消掉 warning
3. 参数元数据补全
4. 飞行模式 + 任务项
5. Tuning & Setup 复制改造
6. FlyView 守卫
7. Checklist + 图标
8. 测试 + SITL 脚本
9. PR 走 `custom-example/`

---

## 16. 常见陷阱与最佳实践

> 摘自 [`CODING_STYLE.md`](file:///home/hex/qgroundcontrol/CODING_STYLE.md) 的 "Common Pitfalls" 与历次机器评审发现。

### 16.1 代码层

- **不要**自建参数/枚举存储 —— 用 Fact
- **不要**写 `Q_ASSERT` 验业务条件 —— 走防御式 `if (!vehicle) return;`
- **不要**在通用代码里写固件字面量（"PX4"、"ArduPilot"、具体命令名）—— 走 FirmwarePlugin
- **不要**保留 Vehicle 指针在 QML 端 —— 用 `activeVehicle`
- **不要**写 `qApp` 默认宏 —— QGC 重定义了 `qApp` 为 `QGCApplication*`
- **必须** 4 空格缩进，LF 行尾
- **必须** 私有成员 `_leadingUnderscore`；常量 `UPPER_SNAKE_CASE`；类 PascalCase；方法/变量 camelCase
- **必须** `[[nodiscard]]` 标注返回错误码的函数
- **必须** C++20：`std::string_view` / `std::span` / designated initializers
- **必须** 用 `Q_OBJECT` + `QML_ELEMENT` / `QML_UNCREATABLE` / `Q_PROPERTY` 暴露给 QML
- **必须** 业务枚举对 QML 用 `Q_ENUM(...)`
- **必须** pre-commit 钩子全过（clang-format、clang-tidy、qmllint、vehicle-null-check、check-no-qassert 等 11 项）

### 16.2 评审导向

[AGENTS.md:13-15](file:///hex/qgroundcontrol/AGENTS.md#L13-L15) 明确：**代码会被另一个 AI 评审 agent 二次审核**。要做到：

- 提交聚焦（一次 PR 一个目的）
- 命名清晰
- commit message 解释"为什么"而非"做了什么"
- 不夹带无关重构、不留注释掉的代码、不留模糊 TODO

### 16.3 跨平台

- iOS **不**支持 `SerialPort`（`src/CMakeLists.txt:28` 显式关闭）
- Windows / Linux / macOS 差异主要在 cmake 平台预设（[`cmake/platform/`](file:///home/hex/qgroundcontrol/cmake/platform/)）
- Android 通过 [`android/`](file:///home/hex/qgroundcontrol/android/) 单独配置 + gradle wrapper

### 16.4 性能

- 用 `FactGroup::setSendValueChangedSignals(false)` 节流高频更新
- `QGCApplication::addCompressedSignal` 自带"信号压缩"
- 视频走 GStreamer / FFmpeg 单独管线，不要进 Qt event loop
- MAVLink 消息频率用 `MessageIntervalManager` 按需调整

### 16.5 调试

- 启详细日志：`QGC_LOG_LEVEL=debug` + `QGC_LOG_SUBSYSTEM=Foo,Bar` 环境变量
- MockLink 离线调试：设置 `MAVLinkProtocol` 入口，连接 `udp://127.0.0.1:14550` 的 SITL
- 日志位置：Linux `~/.local/share/QGroundControl/`，包含 `.log`、`.tlog`、崩溃栈
- LSP 服务：[`tools/lsp/`](file:///home/hex/qgroundcontrol/tools/lsp/) 提供 Fact / MAVLink 跳转

---

## 附录 A：阅读路线图

新成员推荐的源码阅读顺序：

1. [`AGENTS.md`](file:///home/hex/qgroundcontrol/AGENTS.md) + [`CODING_STYLE.md`](file:///home/hex/qgroundcontrol/CODING_STYLE.md) + [`.github/CONTRIBUTING.md`](file:///home/hex/qgroundcontrol/.github/CONTRIBUTING.md)
2. [`src/main.cc`](file:///home/hex/qgroundcontrol/src/main.cc) + [`QGCApplication.h`](file:///home/hex/qgroundcontrol/src/QGCApplication.h)
3. [`src/FactSystem/Fact.h`](file:///home/hex/qgroundcontrol/src/FactSystem/Fact.h) → `FactGroup` → `FactMetaData`
4. [`src/Vehicle/Vehicle.h`](file:///home/hex/qgroundcontrol/src/Vehicle/Vehicle.h) + [`Vehicle.cc`](file:///home/hex/qgroundcontrol/src/Vehicle/Vehicle.cc)
5. [`src/FirmwarePlugin/FirmwarePlugin.h`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/FirmwarePlugin.h) + [`PX4FirmwarePlugin.cc`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/PX4/PX4FirmwarePlugin.cc)
6. [`src/MissionManager/`](file:///home/hex/qgroundcontrol/src/MissionManager/) + [`src/PlanView/`](file:///home/hex/qgroundcontrol/src/PlanView/)
7. [`src/FlyView/FlyView.qml`](file:///home/hex/qgroundcontrol/src/FlyView/FlyView.qml) + [`src/Toolbar/`](file:///home/hex/qgroundcontrol/src/Toolbar/) + [`src/QmlControls/`](file:///home/hex/qgroundcontrol/src/QmlControls/)

## 附录 B：关键文件索引

| 关注点 | 入口文件 |
|--------|----------|
| 启动 | [`src/main.cc`](file:///home/hex/qgroundcontrol/src/main.cc) |
| 应用对象 | [`src/QGCApplication.h`](file:///home/hex/qgroundcontrol/src/QGCApplication.h) |
| Fact | [`src/FactSystem/Fact.h`](file:///home/hex/qgroundcontrol/src/FactSystem/Fact.h) |
| Vehicle | [`src/Vehicle/Vehicle.h`](file:///home/hex/qgroundcontrol/src/Vehicle/Vehicle.h) |
| FirmwarePlugin | [`src/FirmwarePlugin/FirmwarePlugin.h`](file:///home/hex/qgroundcontrol/src/FirmwarePlugin/FirmwarePlugin.h) |
| MAVLink | [`src/MAVLink/QGCMAVLink.h`](file:///home/hex/qgroundcontrol/src/MAVLink/QGCMAVLink.h) |
| Link | [`src/Comms/LinkManager.h`](file:///home/hex/qgroundcontrol/src/Comms/LinkManager.h) |
| MAVLink 协议 | [`src/Comms/MAVLinkProtocol.h`](file:///home/hex/qgroundcontrol/src/Comms/MAVLinkProtocol.h) |
| 飞控配置 | [`src/AutoPilotPlugins/AutoPilotPlugin.h`](file:///home/hex/qgroundcontrol/src/AutoPilotPlugins/AutoPilotPlugin.h) |
| 任务 | [`src/MissionManager/Section.h`](file:///home/hex/qgroundcontrol/src/MissionManager/Section.h) |
| 主窗口 | [`src/MainWindow/MainWindow.qml`](file:///home/hex/qgroundcontrol/src/MainWindow/MainWindow.qml) |
| 飞行视图 | [`src/FlyView/FlyView.qml`](file:///home/hex/qgroundcontrol/src/FlyView/FlyView.qml) |
| 任务规划 | [`src/PlanView/PlanView.qml`](file:///home/hex/qgroundcontrol/src/PlanView/PlanView.qml) |
| 工具栏 | [`src/Toolbar/FlyViewToolBar.qml`](file:///home/hex/qgroundcontrol/src/Toolbar/FlyViewToolBar.qml) |
| 主 CMake | [`CMakeLists.txt`](file:///home/hex/qgroundcontrol/CMakeLists.txt) |
| 源码 CMake | [`src/CMakeLists.txt`](file:///home/hex/qgroundcontrol/src/CMakeLists.txt) |
| 开发任务 | [`justfile`](file:///home/hex/qgroundcontrol/justfile) |
| 开发脚本 | [`tools/README.md`](file:///home/hex/qgroundcontrol/tools/README.md) |
| CI 概览 | [`.github/ci-overview.md`](file:///home/hex/qgroundcontrol/.github/ci-overview.md) |
| 测试 | [`test/TESTING.md`](file:///home/hex/qgroundcontrol/test/TESTING.md) |
| 编码规范 | [`CODING_STYLE.md`](file:///home/hex/qgroundcontrol/CODING_STYLE.md) |
| AI 代理手册 | [`AGENTS.md`](file:///home/hex/qgroundcontrol/AGENTS.md) |

---

*文档版本：基于 QGC master 截至 `AGENTS.md` 当前形态。*
*如发现事实变更，请提交 PR 同步本文档。*
