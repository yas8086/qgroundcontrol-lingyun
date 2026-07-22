# 灵云01号飞艇 QGC + PX4 二次开发完整记录

> 本文档完整记录了 Lingyun01 飞艇基于 QGroundControl 和 PX4-Autopilot 的全部二次开发内容。
> 文档分为 QGC 端和 PX4 固件端两大部分，涵盖所有新增文件、修改文件及其完整逻辑。

---

## 目录

- [一、开发概览](#一开发概览)
- [二、QGC 端二次开发](#二qgc-端二次开发)
  - [2.1 飞艇类型识别与固件插件](#21-飞艇类型识别与固件插件)
  - [2.2 飞行模式映射](#22-飞行模式映射)
  - [2.3 参数页面定制](#23-参数页面定制)
  - [2.4 FlyView 仪表盘 HUD](#24-flyview-仪表盘-hud)
  - [2.5 起飞前检查清单](#25-起飞前检查清单)
  - [2.6 任务规划适配](#26-任务规划适配)
  - [2.7 安全组件适配](#27-安全组件适配)
  - [2.8 MockLink 支持](#28-mocklink-支持)
  - [2.9 FactGroup 注册](#29-factgroup-注册)
  - [2.10 Airframe 元数据](#210-airframe-元数据)
  - [2.11 构建系统修改](#211-构建系统修改)
- [三、PX4 固件端二次开发](#三px4-固件端二次开发)
  - [3.1 ballast_setpoint 消息扩展](#31-ballast_setpoint-消息扩展)
  - [3.2 ballast_control 模块修改](#32-ballast_control-模块修改)
  - [3.3 新增参数定义](#33-新增参数定义)
- [四、数据流与通信架构](#四数据流与通信架构)
- [五、文件清单总览](#五文件清单总览)
- [六、编译与测试验证](#六编译与测试验证)

---

## 一、开发概览

### 项目背景
- **飞艇型号**: 灵云01号 (Lingyun01)
- **MAVLink 类型**: `MAV_TYPE_AIRSHIP` (7)
- **固件类型**: `MAV_AUTOPILOT_PX4`
- **物理特性**: 中性浮力飞艇，4自由度控制（Thrust X/Z, Torque Y/Z），无 Roll 气动控制
- **特殊机制**: 4 空气囊浮力差横滚控制（左右各内/外两个气囊）

### 核心开发内容
| 模块 | QGC 端 | PX4 端 |
|------|--------|--------|
| 飞艇类型识别 | ✅ FirmwarePluginFactory | ✅ airframe 配置 |
| 飞行模式映射 | ✅ AirshipFirmwarePlugin | ✅ custom_mode 0-8 |
| 参数页面 | ✅ 4 个调参页面 | ✅ 30+ 参数定义 |
| HUD 仪表盘 | ✅ AirshipBallastHUD | ✅ NAMED_VALUE_FLOAT 发送 |
| 预飞检查 | ✅ AirshipChecklist | - |
| 安全组件 | ✅ SafetyAirship.VehicleConfig.json | ✅ NAV_FAILSAFE 参数 |
| MockLink | ✅ Airship MockLink | - |
| 横滚控制 | ✅ 参数页面 | ✅ 四气囊主动控制算法 |

---

## 二、QGC 端二次开发

### 2.1 飞艇类型识别与固件插件

#### 新增文件：`src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.h`

飞艇专用固件插件头文件，继承自 `PX4FirmwarePlugin`，重写以下方法：

```cpp
class AirshipFirmwarePlugin : public PX4FirmwarePlugin
{
    Q_OBJECT
public:
    AirshipFirmwarePlugin();
    ~AirshipFirmwarePlugin();

    // 飞行模式映射
    QStringList flightModes(Vehicle* vehicle) const override;
    QString flightMode(uint8_t base_mode, uint32_t custom_mode) const override;
    bool setFlightMode(const QString& flightMode, uint8_t* base_mode, uint32_t* custom_mode) const override;

    // 任务命令覆盖
    QString missionCommandOverrides(QGCMAVLink::VehicleClass_t vehicleClass) const override;

    // 工具栏扩展指示器
    QVariant expandedToolbarIndicatorSource(const Vehicle* vehicle, const QString& indicatorName) const override;

    // 飞行模式名称
    QString pauseFlightMode() const override;
    QString missionFlightMode() const override;
    QString landFlightMode() const override;
    QString takeOffFlightMode() const override;
    QString takeControlFlightMode() const override;
    QString gotoFlightMode() const override;
    QString stabilizedFlightMode() const override;
};
```

#### 新增文件：`src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.cc`

**关键逻辑**：
- 飞艇使用简化的 `custom_mode` 值（0-8），与标准 PX4 的位域编码完全不同
- 9 种飞行模式映射（含 Failsafe=7, Task=8）
- Failsafe 不可手动设置，由系统自动触发

```cpp
namespace AirshipCustomMode {
    constexpr uint32_t MANUAL    = 0;
    constexpr uint32_t STABLE    = 1;
    constexpr uint32_t ALTITUDE  = 2;
    constexpr uint32_t POSITION  = 3;
    constexpr uint32_t OFFBOARD  = 4;
    constexpr uint32_t TAKEOFF   = 5;
    constexpr uint32_t LAND      = 6;
    constexpr uint32_t FAILSAFE  = 7;  // v2.0 新增
    constexpr uint32_t TASK      = 8;  // v2.0 从 7 改为 8
}
```

**可设置模式列表**（Failsafe 不可手动设置）：
| 模式 | Custom Mode | 可设置 |
|------|-------------|--------|
| Manual | 0 | ✅ |
| Stabilized | 1 | ✅ |
| Altitude | 2 | ✅ |
| Position | 3 | ✅ |
| Offboard | 4 | ✅ |
| Takeoff | 5 | ❌（系统触发） |
| Land | 6 | ❌（系统触发） |
| Failsafe | 7 | ❌（系统触发） |
| Mission | 8 | ✅ |

#### 修改文件：`src/FirmwarePlugin/PX4/PX4FirmwarePluginFactory.cc` / `.h`

**修改逻辑**：在工厂方法中添加飞艇类型识别，当 `vehicleType == MAV_TYPE_AIRSHIP` 时创建 `AirshipFirmwarePlugin` 实例：

```cpp
FirmwarePlugin* PX4FirmwarePluginFactory::firmwarePluginForAutopilot(MAV_AUTOPILOT autopilotType, MAV_TYPE vehicleType)
{
    if (autopilotType == MAV_AUTOPILOT_PX4) {
        // 飞艇使用专用的固件插件
        if (vehicleType == MAV_TYPE_AIRSHIP) {
            if (!_airshipPluginInstance) {
                _airshipPluginInstance = new AirshipFirmwarePlugin();
            }
            return _airshipPluginInstance;
        }
        // ... 标准 PX4
    }
    return nullptr;
}
```

新增成员变量 `_airshipPluginInstance` 用于缓存飞艇插件实例。

---

### 2.2 飞行模式映射

#### 新增文件：`src/FirmwarePlugin/PX4/PX4AirshipFlightModeIndicator.qml`

飞艇专用工具栏扩展指示器，显示飞艇关键参数：

**功能**：
- **Flight Limits 组**: 最大爬升率（AS_ALT_VMAX）、最大水平速度（AS_VEL_XY_MAX）、起飞高度（AS_TAKEOFF_ALT）
- **Buoyancy Control 组**: 浮力辅助开关（BALLOON_AST_EN）、高度死区（BALLOON_DEADZONE）、切换阈值（BALLOON_THRSHLD）

通过 `expandedToolbarIndicatorSource()` 在 `AirshipFirmwarePlugin.cc` 中注册。

---

### 2.3 参数页面定制

#### 修改文件：`src/AutoPilotPlugins/PX4/PX4TuningComponent.cc`

**修改逻辑**：在 `setupSource()` 中添加 `MAV_TYPE_AIRSHIP` 分支，加载飞艇调参页面：

```cpp
case MAV_TYPE_AIRSHIP:
    qmlFile = "qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/PX4TuningComponentAirship.qml";
    break;
```

#### 新增文件：`src/AutoPilotPlugins/PX4/PX4TuningComponentAirship.qml`

飞艇调参页面入口，使用 `PX4TuningComponent` 基类 + `ListModel` 组织 3 个子页面：
- Attitude（姿态控制）
- Position（位置控制）
- Ballast（浮力控制）

#### 新增文件：`src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipAll.qml`

```qml
PX4TuningComponent {
    model: ListModel {
        ListElement { buttonText: qsTr("Attitude"); tuningPage: "PX4TuningComponentAirshipAttitude.qml" }
        ListElement { buttonText: qsTr("Position"); tuningPage: "PX4TuningComponentAirshipPosition.qml" }
        ListElement { buttonText: qsTr("Ballast");  tuningPage: "PX4TuningComponentAirshipBallast.qml" }
    }
}
```

#### 新增文件：`src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipAttitude.qml`

**5 个参数组**：

1. **Pitch Outer Loop (Angle)** - 俯仰角外环 PID
   - `AS_PIT_P`, `AS_PIT_I`, `AS_PIT_IMAX`, `AS_PIT_FF`

2. **Pitch Rate Inner Loop** - 俯仰角速率内环 PID
   - `AS_PR_P`, `AS_PR_I`, `AS_PR_D`, `AS_PR_IMAX`

3. **Yaw Outer Loop (Angle)** - 偏航角外环 PID
   - `AS_YAW_P`, `AS_YAW_I`, `AS_YAW_IMAX`, `AS_YAW_TMAX`

4. **Yaw Rate Inner Loop** - 偏航角速率内环 PID
   - `AS_YR_P`, `AS_YR_I`, `AS_YR_D`, `AS_YR_IMAX`

5. **Rate Limits** - 角速率限制
   - `AS_PIT_RMAX`, `AS_YAW_RMAX`

**特性**：参数不存在时显示提示信息 "Airship attitude parameters (AS_*) not found"

#### 新增文件：`src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipPosition.qml`

**7 个参数组**：

1. **Altitude Control** - 高度 PID
   - `AS_ALT_P`, `AS_ALT_I`, `AS_ALT_D`, `AS_ALT_IMAX`, `AS_ALT_VMAX`, `AS_ALT_VFF`

2. **Altitude Limits** - 高度限位
   - `AS_ALT_MAX`, `AS_ALT_MIN`, `AS_ALT_SOFT`, `AS_ALT_SRATE`

3. **Horizontal Position & Velocity** - 水平位置/速度控制
   - `AS_VEL_XY_P`, `AS_VEL_XY_I`, `AS_VEL_XY_D`, `AS_VEL_XY_IMAX`
   - `AS_POS_XY_P`, `AS_VEL_XY_MAX`, `AS_POS_XY_MAX`

4. **Takeoff** - 起飞参数
   - `AS_TAKEOFF_ALT`, `AS_TKF_HOLD_T`, `AS_TKF_ALT_TOL`, `AS_TAKEOFF_RAMP`

5. **Land (Staged Descent)** - 分阶段降落速度
   - `AS_LND_DONE_ALT`, `AS_LND_VHI`, `AS_LND_VMID`, `AS_LND_VLO`, `AS_LND_VGND`

6. **Auto Test & Tuning (Advanced)** - 自动测试/调参
   - `AS_TST_EN`, `AS_TST_PIT`, `AS_TST_YAW`
   - `AS_AT_EN`, `AS_AT_AMP`, `AS_AT_DUR`

#### 新增文件：`src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipBallast.qml`

**6 个参数组**：

1. **Buoyancy Assist Control** - 浮力辅助控制
   - `BALLOON_AST_EN`, `BALLOON_DEADZONE`, `BALLOON_THRSHLD`, `BALLOON_RATE_MAX`

2. **Buoyancy PID** - 浮力 PID
   - `BALLOON_P_GAIN`, `BALLOON_I_GAIN`, `BALLOON_D_GAIN`, `BALLOON_I_MAX`

3. **Blower & Valve** - 鼓风机与阀门
   - `BLOWER_TAU`, `VALVE_OPEN_DELAY`

4. **Left-Right Buoyancy Trim** - 左右浮力配平
   - `TRIM_BALLOON_EN`, `TRIM_BALLOON_P`, `TRIM_BALLOON_I`, `TRIM_BALLOON_IMX`

5. **Roll Control (4-Ballast Active)** - 横滚主动控制（四气囊浮力差）
   - `BALLOON_R_EN`, `BALLOON_R_P`, `BALLOON_R_I`, `BALLOON_R_IMX`
   - `BALLOON_RR_P`, `BALLOON_RR_D`
   - `BALLOON_R_MAX`, `BALLOON_M_MAX`

6. **Blower & Valve Actuator** - 执行器参数
   - `BLWR_FLOW`, `VALVE_HYST`, `VALVE_MIN_T`

---

### 2.4 FlyView 仪表盘 HUD

#### 新增文件：`src/FlyView/AirshipBallastHUD.qml`

飞艇专用 HUD 面板，显示浮力控制状态。**仅在 `vehicleType === 7` (MAV_TYPE_AIRSHIP) 时显示**。

**显示元素**：

1. **标题行 + 浮力平衡指示器**
   - 标题: "Ballast Control"
   - 浮力平衡: `|净浮力| < 0.5N` 时显示绿色"浮力平衡"标签

2. **飞行模式状态指示器**（动态显示）
   - Takeoff 模式: 蓝色背景 `▲ 起飞中`
   - Land 模式: 橙色背景 `▼ 降落中`
   - Failsafe 模式: 红色背景 `⚠ Failsafe`
   - 起飞/降落时: `推进电机: OFF`

3. **净浮力数值**（带颜色指示）
   - `> 0.5N`: 警告色（黄色）
   - `< -0.5N`: 危险色（红色）
   - 其他: 正常色

4. **4 个 ProgressBar** 显示鼓风机/阀门输出
   - Blower L (左鼓风机)
   - Blower R (右鼓风机)
   - Valve L (左阀门)
   - Valve R (右阀门)

5. **高度误差数值**（`> 2.0m` 时警告色）

**数据流调试日志**：
- `Component.onCompleted`: 打印初始化信息
- `onVisibleChanged`: 打印可见性变化
- 1Hz Timer: 打印所有 Fact 值

**属性定义**：
```qml
property var    _activeVehicle:     globals.activeVehicle
property var    _ballast:           _activeVehicle ? _activeVehicle.ballast : null
property string _flightMode:        _activeVehicle ? _activeVehicle.flightMode : ""
property bool   _isTakeoff:         _flightMode === "Takeoff"
property bool   _isLand:            _flightMode === "Land"
property bool   _isFailsafe:        _flightMode === "Failsafe"
property bool   _propulsionOff:     _isTakeoff || _isLand
```

#### 修改文件：`src/FlyView/FlyViewWidgetLayer.qml`

在左下角添加 AirshipBallastHUD 组件：

```qml
// 飞艇浮力控制 HUD 面板（仅在飞艇类型时显示）
AirshipBallastHUD {
    anchors.bottom:        parent.bottom
    anchors.left:          parent.left
    anchors.margins:       _toolsMargin
}
```

---

### 2.5 起飞前检查清单

#### 新增文件：`src/FlyView/AirshipChecklist.qml`

飞艇专用预飞检查清单，包含 3 组检查：

**第一组：Airship Initial Checks（初始检查）**
- Hardware: 飞艇气囊完整性、鼓风机/阀门响应、电机安装
- Battery Check: 40% 电量阈值
- Sensors Health Check: 传感器健康
- GPS Check: 9 颗卫星阈值（可覆盖）
- RC Check: 遥控器检查

**第二组：Airship-Specific Checks（飞艇专用检查）**
- Buoyancy: 净浮力接近零、左右配平平衡、鼓风机/阀门响应
- Altitude Limits: AS_ALT_MAX/MIN 设置、当前高度低于 AS_TAKEOFF_ALT
- Mission: 任务有效、航点间距 >50m、转弯角度 <30°、降落区清晰
- Sound Check: 声音检查

**第三组：Final Preparations Before Launch（最终准备）**
- Wind & Weather: 风速在飞艇操作限制内
- Flight Area: 起降区域清晰、飞行路径无障碍
- Envelope Pressure: 氦气压力正常、无泄漏

#### 修改文件：`src/FlyView/PreFlightCheckList.qml`

在 `_updateModel()` 中添加飞艇类型判断：

```qml
} else if(vehicle.airship) {
    modelContainer.source = "qrc:/qml/QGroundControl/FlyView/AirshipChecklist.qml"
}
```

---

### 2.6 任务规划适配

#### 新增文件：`src/FirmwarePlugin/PX4/PX4-MavCmdInfoAirship.json`

飞艇专用任务命令配置，针对飞艇大惯量特性简化任务命令：

```json
{
    "mavCmdInfo": [
        {
            "id": 22,
            "comment": "MAV_CMD_NAV_TAKEOFF - Airship vertical climb, only altitude is settable",
            "paramRemove": "1,2,3,4,5,6"
        },
        {
            "id": 16,
            "comment": "MAV_CMD_NAV_WAYPOINT - Airship waypoint, large inertia requires planning",
            "paramRemove": "2,3"
        },
        {
            "id": 21,
            "comment": "MAV_CMD_NAV_LAND - Airship land, consider drift",
            "paramRemove": "1"
        }
    ]
}
```

**说明**：
- Takeoff: 移除所有参数（仅保留高度），飞艇垂直爬升
- Waypoint: 移除参数 2/3，飞艇大惯量需要专门规划
- Land: 移除参数 1，考虑漂移

通过 `AirshipFirmwarePlugin::missionCommandOverrides()` 注册。

---

### 2.7 安全组件适配

#### 修改文件：`src/AutoPilotPlugins/PX4/SafetyComponent.cc`

添加飞艇专用安全配置判断：

```cpp
QString SafetyComponent::vehicleConfigJson(void) const
{
    if (_vehicle && _vehicle->vehicleType() == MAV_TYPE_AIRSHIP) {
        return QStringLiteral(":/qml/QGroundControl/AutoPilotPlugins/PX4/VehicleConfig/SafetyAirship.VehicleConfig.json");
    }
    return QStringLiteral(":/qml/QGroundControl/AutoPilotPlugins/PX4/VehicleConfig/Safety.VehicleConfig.json");
}
```

新增 `#include "Vehicle.h"` 解决类型不完整错误。

#### 新增文件：`src/AutoPilotPlugins/PX4/VehicleConfig/SafetyAirship.VehicleConfig.json`

飞艇专用安全组件配置，包含 7 个 section：

1. **Low Battery Failsafe**: `COM_LOW_BAT_ACT`, `BAT_LOW_THR`, `BAT_CRIT_THR`, `BAT_EMERGEN_THR`
2. **RC/Joystick Loss Failsafe**: `NAV_RCL_ACT`, `COM_RC_LOSS_T`
3. **Data Link Loss Failsafe**: `NAV_DLL_ACT`, `COM_DL_LOSS_T`
4. **Geofence Failsafe**: `GF_ACTION`, `GF_MAX_HOR_DIST`, `GF_MAX_VER_DIST`
5. **Airship Flight Limits**: `AS_ALT_VMAX`, `AS_VEL_XY_MAX`, `AS_TAKEOFF_ALT`
6. **Airship Buoyancy Safety**: `BALLOON_AST_EN`, `BALLOON_RATE_MAX`, `BALLOON_DEADZONE`, `TRIM_BALLOON_EN`
7. **Land Mode Settings**: `COM_DISARM_LAND`

---

### 2.8 MockLink 支持

#### 修改文件：`src/Comms/MockLink/MockLink.cc` / `.h`

**修改逻辑**：
1. 添加 `startAirshipMockLink()` 静态方法
2. 在 `_loadParams()` 中根据 `_vehicleType` 加载飞艇参数文件
3. 飞艇初始 `custom_mode` 设置为 0 (Manual)

```cpp
MockLink *MockLink::startAirshipMockLink(bool sendStatusText, bool enableCamera, bool enableGimbal, MockConfiguration::FailureMode_t failureMode)
{
    return _startMockLinkWorker(QStringLiteral("PX4 Airship MockLink"), MAV_AUTOPILOT_PX4, MAV_TYPE_AIRSHIP, sendStatusText, enableCamera, enableGimbal, failureMode);
}
```

#### 修改文件：`src/AppSettings/MockLinkSettings.qml`

**修改逻辑**：添加飞艇选项到 MockLink 配置 UI

```qml
readonly property int _MAV_TYPE_AIRSHIP: 7

// PX4 固件时显示 MultiRotor / Airship 选项
model: firmwareTypeCombo.px4FirmwareSelected
        ? [ qsTr("MultiRotor"), qsTr("Airship") ]
        : (firmwareTypeCombo.apmFirmwareSelected
            ? [ qsTr("ArduCopter"), qsTr("ArduPlane") ]
            : [])
```

#### 新增文件：`src/Comms/MockLink/PX4MockLinkAirship.params`

飞艇 Mock 参数文件，包含 50+ 个飞艇专用参数：
- `AS_*`: 姿态/位置控制参数（AS_ALT_*, AS_PIT_*, AS_YAW_*, AS_PR_*, AS_YR_*, AS_VEL_XY_*, AS_POS_XY_*, AS_TAKEOFF_*, AS_TKF_*, AS_LND_*）
- `BALLOON_*`: 浮力控制参数（BALLOON_AST_EN, BALLOON_P_GAIN, BALLOON_I_GAIN, BALLOON_D_GAIN, BALLOON_DEADZONE, BALLOON_THRSHLD, BALLOON_RATE_MAX, BALLOON_I_MAX）
- `TRIM_BALLOON_*`: 左右配平参数
- `BLOWER_TAU`, `VALVE_OPEN_DELAY`: 执行器参数

---

### 2.9 FactGroup 注册

#### 新增文件：`src/Vehicle/FactGroups/AirshipBallastFactGroup.h` / `.cc`

飞艇浮力控制状态 FactGroup，接收 PX4 通过 NAMED_VALUE_FLOAT 消息发送的 ballast_setpoint 字段。

**6 个 Fact 属性**：

| QML 属性 | NAMED_VALUE_FLOAT name | 说明 | 单位 |
|----------|----------------------|------|------|
| `netBuoyancy` | `buoy` | 净浮力 | N |
| `blowerLeft` | `blw_l` | 左鼓风机输出 [0,1] | - |
| `blowerRight` | `blw_r` | 右鼓风机输出 [0,1] | - |
| `valveLeft` | `vlv_l` | 左阀门输出 [0,1] | - |
| `valveRight` | `vlv_r` | 右阀门输出 [0,1] | - |
| `altitudeError` | `alt_err` | 高度误差 | m |

**消息处理逻辑**：
```cpp
void AirshipBallastFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_NAMED_VALUE_FLOAT) {
        return;
    }

    mavlink_named_value_float_t namedValue;
    mavlink_msg_named_value_float_decode(&message, &namedValue);

    // 解码 name 字段（确保 null 结尾）
    char name[MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN + 1];
    memcpy(name, namedValue.name, MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN);
    name[MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN] = '\0';
    const QString nameStr = QString::fromLatin1(name).trimmed();

    // 根据 name 分发到对应 Fact
    if (nameStr == QStringLiteral("buoy")) {
        _netBuoyancyFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blw_l")) {
        _blowerLeftFact.setRawValue(namedValue.value);
    }
    // ... 其他字段

    _setTelemetryAvailable(true);
}
```

#### 修改文件：`src/Vehicle/Vehicle.h` / `.cc`

**Vehicle.h 修改**：
- 添加 `#include "AirshipBallastFactGroup.h"`
- 添加 `Q_PROPERTY(FactGroup* ballast READ ballastFactGroup CONSTANT)`
- 添加访问函数 `FactGroup* ballastFactGroup() { return _ballastFactGroup; }`
- 添加名称常量 `const QString _ballastFactGroupName = QStringLiteral("ballast");`
- 添加成员变量 `AirshipBallastFactGroup* _ballastFactGroup = nullptr;`

**Vehicle.cc 修改**：
- 在 `_commonInit()` 中创建实例: `_ballastFactGroup = new AirshipBallastFactGroup(this);`
- 注册到 FactGroup 系统: `_addFactGroup(_ballastFactGroup, _ballastFactGroupName);`

---

### 2.10 Airframe 元数据

#### 修改文件：`src/AutoPilotPlugins/PX4/AirframeFactMetaData.xml`

新增 Airframe 组和 Lingyun01 机型定义：

```xml
<airframe_group name="Airship" image="Airship">
    <airframe name="Cloudship" id="2507" maintainer="John Doe &lt;john@example.com&gt;">
        <class>Airship</class>
        <type>Airship</type>
        <output name="Motor1">starboard thruster</output>
        <output name="Motor2">port thruster</output>
        <output name="Motor3">tail thruster</output>
        <output name="Servo1">thrust tilt</output>
    </airframe>
    <airframe name="Lingyun01" id="4022" maintainer="Lingyun Realm Aviation &lt;dev@lingyun-aero.com&gt;">
        <class>Airship</class>
        <type>Airship</type>
        <output name="Motor1">lift motor 0 (ccw)</output>
        <output name="Motor2">lift motor 1 (cw)</output>
        <output name="Motor3">lift motor 2 (cw)</output>
        <output name="Motor4">lift motor 3 (ccw)</output>
        <output name="Motor5">thrust motor 4 (ccw)</output>
        <output name="Motor6">thrust motor 5 (cw)</output>
        <output name="Motor7">thrust motor 6 (ccw)</output>
        <output name="Motor8">thrust motor 7 (cw)</output>
        <output name="Motor9">blower left</output>
        <output name="Motor10">blower right</output>
        <output name="Motor11">valve left</output>
        <output name="Motor12">valve right</output>
    </airframe>
</airframe_group>
```

**Lingyun01 机型输出定义**：
- Motor 1-4: 升力电机（4 个，ccw/cw 交替）
- Motor 5-8: 推进电机（4 个，ccw/cw 交替）
- Motor 9-10: 左右鼓风机
- Motor 11-12: 左右阀门

---

### 2.11 构建系统修改

#### `src/FirmwarePlugin/PX4/CMakeLists.txt`
- 添加 `AirshipFirmwarePlugin.cc` 和 `AirshipFirmwarePlugin.h` 到源文件
- 添加 `PX4AirshipFlightModeIndicator.qml` 到 QML 模块

#### `src/AutoPilotPlugins/PX4/CMakeLists.txt`
- 添加 5 个飞艇调参 QML 文件到 QML 模块
- 添加 `SafetyAirship.VehicleConfig.json` 到 RESOURCES

#### `src/FlyView/CMakeLists.txt`
- 添加 `AirshipBallastHUD.qml` 和 `AirshipChecklist.qml` 到 QML 模块

#### `src/Vehicle/FactGroups/CMakeLists.txt`
- 添加 `AirshipBallastFactGroup.cc` 和 `AirshipBallastFactGroup.h` 到源文件

#### `src/Comms/MockLink/CMakeLists.txt`
- 添加 `PX4MockLinkAirship.params` 到资源文件

---

## 三、PX4 固件端二次开发

### 3.1 ballast_setpoint 消息扩展

#### 修改文件：`msg/ballast_setpoint.msg`

**扩展字段**（在原有 6 个字段基础上新增横滚控制字段）：

```
float32 net_buoyancy         # 净浮力调整量 (N)
float32 blower_left          # 左鼓风机输出 [0,1] (旧字段, 保留兼容)
float32 blower_right         # 右鼓风机输出 [0,1] (旧字段, 保留兼容)
float32 valve_left           # 左阀门输出 [0,1] (旧字段, 保留兼容)
float32 valve_right          # 右阀门输出 [0,1] (旧字段, 保留兼容)
float32 altitude_error       # 当前高度误差 (m)

# 横滚控制字段 (四气囊空气囊系统)
float32 roll_moment_demand   # 横滚力矩需求 [-1,1]

# 四气囊当前空气质量估计 (kg)
# 索引: 0=LI(右内), 1=LO(右外), 2=RI(左内), 3=RO(左外)
float32[4] ballast_mass

# 四气囊执行器命令 (0或1, 开关型)
uint8[4] ballast_blower_in   # 充气风机命令
uint8[4] ballast_blower_out  # 抽气风机命令
uint8[4] ballast_valve_in    # 充气阀门命令
uint8[4] ballast_valve_out   # 放气阀门命令
```

### 3.2 ballast_control 模块修改

#### 修改文件：`src/modules/ballast_control/ballast_control_main.cpp`

**核心修改**：

1. **新增 `roll_control()` 方法** - 四气囊横滚主动控制

   独立级联 PID 算法：
   ```
   外环: 横滚角误差 -> 横滚角速度设定值 (P + I)
   内环: 横滚角速度误差 -> 横滚力矩需求 (P + D)
   质量分配器: 横滚力矩 -> 各气囊目标质量变化
   ```

   **关键逻辑**：
   - 外囊承担 70% 力矩，内囊承担 30%（外囊力臂大，效率高）
   - 反对称分配：需要负力矩时左侧(RI/RO)充气，右侧(LI/LO)放气
   - 滞环控制：质量误差超过阈值才切换执行器
   - 质量限制保护：达到上限停止充气，达到下限停止抽气

   ```cpp
   void BallastControl::roll_control(float roll, float roll_rate, float dt)
   {
       // 1. 外环: 横滚角误差 -> 横滚角速度设定值
       float roll_error = 0.f - roll;
       _roll_angle_integral += roll_error * dt;
       _roll_angle_integral = math::constrain(_roll_angle_integral,
                                              -_param_roll_imax.get(), _param_roll_imax.get());
       float roll_rate_setpoint = _param_roll_p.get() * roll_error
                                + _param_roll_i.get() * _roll_angle_integral;

       // 2. 内环: 横滚角速度误差 -> 横滚力矩需求
       float roll_rate_error = roll_rate_setpoint - roll_rate;
       float roll_rate_d = -roll_rate;
       float roll_moment = _param_rollrate_p.get() * roll_rate_error
                         + _param_rollrate_d.get() * roll_rate_d;
       roll_moment = math::constrain(roll_moment, -1.f, 1.f);

       // 3. 质量分配器: 反对称分配到 4 个气囊
       float delta_m_needed = roll_moment * _param_mass_max.get() * 0.5f;
       float delta_m_outer = 0.7f * delta_m_needed;
       float delta_m_inner = 0.3f * delta_m_needed;

       float target_mass[4];
       target_mass[0] = math::constrain(delta_m_inner, 0.f, _param_mass_max.get());  // LI
       target_mass[1] = math::constrain(delta_m_outer, 0.f, _param_mass_max.get());  // LO
       target_mass[2] = math::constrain(-delta_m_inner, 0.f, _param_mass_max.get()); // RI
       target_mass[3] = math::constrain(-delta_m_outer, 0.f, _param_mass_max.get()); // RO

       // 4. 开关执行器逻辑（滞环控制 + 质量保护）
       for (int i = 0; i < 4; i++) {
           float mass_error = target_mass[i] - _ballast_mass[i];
           if (mass_error > _param_valve_hyst.get()) {
               _blower_in_state[i] = 1; _valve_in_state[i] = 1;  // 充气
           } else if (mass_error < -_param_valve_hyst.get()) {
               _blower_out_state[i] = 1; _valve_out_state[i] = 1;  // 放气
           }
           // ... 质量限制保护
       }
   }
   ```

2. **新增 `vehicle_angular_velocity` 订阅** - 获取横滚角速度

3. **修改 `balance_control()` 调用条件** - 横滚控制启用时禁用旧方案
   ```cpp
   // 旧方案: 差动鼓风机
   if (_param_trim_enable.get() && !_param_roll_enable.get()) {
       balance_control(roll, dt);
   }
   // 新方案: 四气囊浮力差
   if (_param_roll_enable.get()) {
       roll_control(roll, roll_rate, dt);
   }
   ```

4. **修复高度误差逻辑** - 中性浮力飞艇不使用绝对高度
   ```cpp
   // 旧代码: _altitude_error = -_current_altitude; (会把 19m 高度当作 -19m 误差)
   // 新代码: 中性浮力飞艇高度由升力电机控制，ballast_control 仅提供垂直速度阻尼
   _altitude_error = 0.0f;
   ```

5. **扩展 `publish_debug()`** - 从 6 个字段扩展到 17 个字段

   新增 debug 字段：
   | Case | Key | 说明 |
   |------|-----|------|
   | 6 | `rol_dmd` | 横滚力矩需求 |
   | 7-10 | `massLI/LO/RI/RO` | 四气囊质量 |
   | 11-14 | `actLI/LO/RI/RO` | 执行器状态（位编码） |
   | 15 | `dbg_rol` | 当前横滚角 |
   | 16 | `dbg_rate` | 当前横滚角速度 |

6. **日志降级** - `PX4_INFO` 改为 `PX4_DEBUG`（避免日志过多）

### 3.3 新增参数定义

#### 修改文件：`src/modules/ballast_control/ballast_control_params.c`

新增 11 个横滚控制参数：

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `BALLOON_R_EN` | INT32 | 1 | 启用横滚主动控制 |
| `BALLOON_R_P` | FLOAT | 2.0 | 横滚角度外环 P 增益 |
| `BALLOON_R_I` | FLOAT | 0.1 | 横滚角度外环 I 增益 |
| `BALLOON_R_IMX` | FLOAT | 0.3 | 横滚角度外环积分限幅 |
| `BALLOON_RR_P` | FLOAT | - | 横滚角速度内环 P 增益 |
| `BALLOON_RR_D` | FLOAT | - | 横滚角速度内环 D 增益 |
| `BALLOON_R_MAX` | FLOAT | - | 横滚力矩最大值 |
| `BALLOON_M_MAX` | FLOAT | - | 单气囊最大质量 |
| `BLWR_FLOW` | FLOAT | - | 鼓风机流量 |
| `VALVE_HYST` | FLOAT | - | 阀门滞环阈值 |
| `VALVE_MIN_T` | FLOAT | - | 阀门最小开启时间 |

---

## 四、数据流与通信架构

### 4.1 完整数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                        PX4 固件端                                │
│                                                                  │
│  ballast_control 模块 (50Hz)                                    │
│    ├─ 浮力辅助控制 (PID)                                        │
│    ├─ 左右配平控制 (差动鼓风机)                                  │
│    └─ 横滚主动控制 (四气囊浮力差)                                │
│         │                                                        │
│         ▼                                                        │
│  ballast_setpoint uORB 消息                                      │
│    ├─ net_buoyancy, blower_*, valve_*, altitude_error           │
│    └─ roll_moment_demand, ballast_mass[4], actuator[4]          │
│         │                                                        │
│         ▼                                                        │
│  publish_debug() - 轮询发布 17 个字段                            │
│    └─ debug_key_value uORB -> mavlink 模块                       │
│         │                                                        │
│         ▼                                                        │
│  NAMED_VALUE_FLOAT MAVLink 消息 (8.3Hz/字段)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ MAVLink 链路
┌─────────────────────────────────────────────────────────────────┐
│                        QGC 端                                    │
│                                                                  │
│  Vehicle::handleMessage()                                       │
│         │                                                        │
│         ▼                                                        │
│  AirshipBallastFactGroup::handleMessage()                       │
│    ├─ 解析 NAMED_VALUE_FLOAT                                     │
│    └─ 根据 name 分发到 6 个 Fact                                │
│         │                                                        │
│         ▼                                                        │
│  QML 层                                                          │
│    ├─ AirshipBallastHUD.qml                                      │
│    │   ├─ 净浮力数值显示 (带颜色指示)                            │
│    │   ├─ 4 个 ProgressBar (鼓风机/阀门)                         │
│    │   ├─ 浮力平衡指示器                                         │
│    │   └─ 飞行模式状态指示器                                     │
│    └─ PX4AirshipFlightModeIndicator.qml                         │
│        ├─ 飞行限制参数                                           │
│        └─ 浮力控制状态                                           │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 关键设计决策

1. **使用 NAMED_VALUE_FLOAT 而非自定义 MAVLink 消息**
   - 原因：避免修改 MAVLink 协议，利用 PX4 内置的 `debug_key_value` uORB → NAMED_VALUE_FLOAT 自动转换
   - 代价：需要轮询发布多个字段（每个字段 8.3Hz）

2. **飞艇使用简化 custom_mode（0-8）**
   - 原因：飞艇飞行模式简单，无需标准 PX4 的位域编码
   - 实现：独立的 `AirshipFirmwarePlugin` 覆盖父类映射

3. **四气囊横滚控制独立于 att_control**
   - 原因：飞艇无气动横滚控制，横滚只能通过浮力差实现
   - 实现：ballast_control 内部独立级联 PID，不依赖 att_control 输出

---

## 五、文件清单总览

### QGC 端 - 新增文件 (13 个)

| # | 文件路径 | 说明 |
|---|---------|------|
| 1 | `src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.h` | 飞艇固件插件头文件 |
| 2 | `src/FirmwarePlugin/PX4/AirshipFirmwarePlugin.cc` | 飞艇固件插件实现 |
| 3 | `src/FirmwarePlugin/PX4/PX4AirshipFlightModeIndicator.qml` | 飞行模式指示器 |
| 4 | `src/FirmwarePlugin/PX4/PX4-MavCmdInfoAirship.json` | 任务命令配置 |
| 5 | `src/AutoPilotPlugins/PX4/PX4TuningComponentAirship.qml` | 调参页面入口 |
| 6 | `src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipAll.qml` | 调参页面容器 |
| 7 | `src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipAttitude.qml` | 姿态参数页面 |
| 8 | `src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipPosition.qml` | 位置参数页面 |
| 9 | `src/AutoPilotPlugins/PX4/PX4TuningComponentAirshipBallast.qml` | 浮力参数页面 |
| 10 | `src/AutoPilotPlugins/PX4/VehicleConfig/SafetyAirship.VehicleConfig.json` | 安全组件配置 |
| 11 | `src/Comms/MockLink/PX4MockLinkAirship.params` | 飞艇 Mock 参数 |
| 12 | `src/FlyView/AirshipBallastHUD.qml` | 浮力控制 HUD |
| 13 | `src/FlyView/AirshipChecklist.qml` | 预飞检查清单 |
| 14 | `src/Vehicle/FactGroups/AirshipBallastFactGroup.h` | 浮力 FactGroup 头文件 |
| 15 | `src/Vehicle/FactGroups/AirshipBallastFactGroup.cc` | 浮力 FactGroup 实现 |

### QGC 端 - 修改文件 (11 个)

| # | 文件路径 | 修改内容 |
|---|---------|---------|
| 1 | `src/FirmwarePlugin/PX4/PX4FirmwarePluginFactory.cc` | 添加飞艇插件创建逻辑 |
| 2 | `src/FirmwarePlugin/PX4/PX4FirmwarePluginFactory.h` | 添加飞艇插件成员变量 |
| 3 | `src/FirmwarePlugin/PX4/CMakeLists.txt` | 注册飞艇插件源文件和 QML |
| 4 | `src/AutoPilotPlugins/PX4/PX4TuningComponent.cc` | 添加飞艇调参页面分支 |
| 5 | `src/AutoPilotPlugins/PX4/SafetyComponent.cc` | 添加飞艇安全配置判断 |
| 6 | `src/AutoPilotPlugins/PX4/AirframeFactMetaData.xml` | 添加 Airship 机型定义 |
| 7 | `src/AutoPilotPlugins/PX4/CMakeLists.txt` | 注册飞艇 QML 文件 |
| 8 | `src/Comms/MockLink/MockLink.cc` | 添加飞艇 MockLink 支持 |
| 9 | `src/Comms/MockLink/MockLink.h` | 添加 startAirshipMockLink 声明 |
| 10 | `src/Comms/MockLink/CMakeLists.txt` | 注册飞艇 Mock 参数 |
| 11 | `src/AppSettings/MockLinkSettings.qml` | 添加飞艇选项到 UI |
| 12 | `src/FlyView/FlyViewWidgetLayer.qml` | 添加 HUD 到左下角 |
| 13 | `src/FlyView/PreFlightCheckList.qml` | 添加飞艇检查清单判断 |
| 14 | `src/FlyView/CMakeLists.txt` | 注册飞艇 QML 文件 |
| 15 | `src/Vehicle/Vehicle.h` | 注册 ballast FactGroup |
| 16 | `src/Vehicle/Vehicle.cc` | 创建 ballast FactGroup 实例 |
| 17 | `src/Vehicle/FactGroups/CMakeLists.txt` | 注册 FactGroup 源文件 |

### PX4 固件端 - 修改文件 (3 个)

| # | 文件路径 | 修改内容 |
|---|---------|---------|
| 1 | `msg/ballast_setpoint.msg` | 扩展横滚控制字段 |
| 2 | `src/modules/ballast_control/ballast_control_main.cpp` | 横滚控制算法 + debug 发布 |
| 3 | `src/modules/ballast_control/ballast_control_params.c` | 新增 11 个横滚控制参数 |

---

## 六、编译与测试验证

### 6.1 编译验证

**QGC 编译**：
```bash
cd /home/hex/qgroundcontrol
cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc)
```
结果：✅ `Linking CXX executable Debug/QGroundControl`

**PX4 固件编译**：
```bash
cd /home/hex/PX4-Autopilot
make px4_sitl default
```
结果：✅ `Linking CXX executable bin/px4`

### 6.2 测试验证

**QGC 单元测试**：
```bash
cd build/Desktop_Qt_6_10_1-Debug/test
ctest -L Vehicle --output-on-failure --parallel 4
```
结果：✅ 26/26 通过（Vehicle 测试）

**QML 测试**：
```bash
ctest -R QmlQuickTests --output-on-failure
```
结果：✅ 通过

**Firmware 测试**：
```bash
ctest -R Firmware -L Unit --output-on-failure
```
结果：✅ `FirmwareUpgradeControllerTest` 通过

### 6.3 功能验证清单

- ✅ QGC 启动正常，无 QML 加载错误
- ✅ 飞艇类型识别（MAV_TYPE_AIRSHIP）
- ✅ 飞行模式映射（9 种模式，含 Failsafe）
- ✅ 参数页面显示（Attitude/Position/Ballast）
- ✅ HUD 面板显示（仅飞艇类型）
- ✅ 预飞检查清单加载
- ✅ MockLink 飞艇选项
- ✅ PX4 固件 ballast_control 模块编译
- ✅ NAMED_VALUE_FLOAT 消息发送
- ✅ 数据流端到端验证

---

## 附录：开发环境

- **QGC 版本**: 基于 master 分支二次开发
- **PX4 版本**: 基于 PX4-Autopilot 定制版
- **Qt 版本**: 6.10.1
- **构建系统**: CMake + Ninja
- **操作系统**: Ubuntu 24.04
- **开发工具**: Qt Creator, VS Code
- **仿真环境**: Gazebo Classic / GZ Sim

---

*文档生成时间: 2026-07-21*
*开发者: Lingyun Realm Aviation*
