# 03 - uORB消息与MAVLink接口

## 1. 自定义uORB消息

### 1.1 ballast_setpoint.msg (浮力控制与横滚控制设定值)

**文件**: `msg/ballast_setpoint.msg`

```c
uint64 timestamp              # time since system start (microseconds)

# 浮力调节系统设定值
# 由 ballast_control 模块独立发布(唯一发布者), Gazebo 插件订阅用于动态浮力调节
# 实飞由 ballast_output 模块订阅, 映射到 actuator_servos

float32 net_buoyancy          # 净浮力调整量 (N), 正=上升, 负=下降
float32 blower_left           # 左鼓风机输出 [0,1] (旧字段, 保留兼容)
float32 blower_right          # 右鼓风机输出 [0,1] (旧字段, 保留兼容)
float32 valve_left            # 左阀门输出 [0,1] (旧字段, 保留兼容)
float32 valve_right           # 右阀门输出 [0,1] (旧字段, 保留兼容)
float32 altitude_error        # 当前高度误差 (m)

# 横滚控制字段 (四气囊空气囊系统)
# 由 ballast_control 独立级联PID计算并发布(不依赖att_control)
float32 roll_moment_demand    # 横滚力矩需求 [-1,1], 正=右侧下沉
float32[4] ballast_mass       # 四气囊空气质量 (kg)
                              # 索引: 0=LI(右内), 1=LO(右外), 2=RI(左内), 3=RO(左外)
                              # 注意: LI/LO在Y正方向(物理右侧), RI/RO在Y负方向(物理左侧)
uint8[4] ballast_blower_in    # 充气风机命令 (0或1)
uint8[4] ballast_blower_out   # 抽气风机命令 (0或1)
uint8[4] ballast_valve_in     # 充气阀门命令 (0或1)
uint8[4] ballast_valve_out    # 放气阀门命令 (0或1)
```

**消息流向**:
```
ballast_control (唯一发布者, 独立横滚PID) → ballast_setpoint → ballast_output (订阅)
                                                         → GZMixingInterfaceBallast → Gazebo插件 (仿真)
```

**架构说明**: ballast_control 独立实现横滚级联PID（角度外环P+I → 角速度内环P+D → 质量分配器 → 开关执行器），从 vehicle_attitude 和 vehicle_angular_velocity 获取反馈，不依赖 att_control。att_control 的 torque_x 置0。

**重要说明**: 此消息仅在PX4内部和Gazebo仿真插件之间使用, **不通过MAVLink发送到QGC**。
QGC如需显示浮力状态,需要从其他MAVLink消息推断(如 `ALTITUDE` 高度误差)。

---

## 2. PX4标准uORB话题(airship_att_control订阅/发布)

### 2.1 订阅话题

| 话题 | 类型 | 用途 |
|------|------|------|
| vehicle_status | uORB | 飞行模式(nav_state)、系统类型、解锁状态 |
| manual_control_setpoint | uORB | 遥控器/虚拟摇杆输入 |
| vehicle_attitude | uORB | 当前姿态四元数 |
| vehicle_local_position | uORB | 本地位置NED |
| vehicle_angular_velocity | uORB | 角速度(内环反馈) |
| vehicle_attitude_setpoint | uORB | Offboard姿态设定值 |
| vehicle_control_mode | uORB | 控制模式标志 |
| offboard_control_mode | uORB | Offboard控制模式 |
| vehicle_land_detected | uORB | 着陆检测状态 |
| trajectory_setpoint | uORB | 轨迹设定值(Task模式) |
| position_setpoint_triplet | uORB | 位置设定值三元组(导航用) |
| failsafe_flags | uORB | failsafe状态标志 |
| parameter_update | uORB | 参数更新通知 |

### 2.2 发布话题

| 话题 | 类型 | 用途 |
|------|------|------|
| vehicle_thrust_setpoint | uORB | 推力设定值 [thrust_x, thrust_y, thrust_z] |
| vehicle_torque_setpoint | uORB | 力矩设定值 [torque_x, torque_y, torque_z] |
| vehicle_command | uORB | 内部命令(如起飞完成后切换模式) |
| takeoff_status | uORB | 起飞状态 |

**关键**: 飞艇通过 `vehicle_thrust_setpoint` 和 `vehicle_torque_setpoint` 与控制分配器通信,控制分配器再输出到 `actuator_motors` 和 `actuator_servos`。

---

## 3. MAVLink消息接口

### 3.1 飞艇类型识别

**关键标识**: `MAV_TYPE_AIRSHIP = 7`

**HEARTBEAT消息字段**:
```c
uint8_t  type              = 7  // MAV_TYPE_AIRSHIP
uint8_t  autopilot         = 3  // MAV_AUTOPILOT_PX4
uint8_t  system_status
uint8_t  base_mode               // 含 MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
uint32_t custom_mode              // 见下方模式映射
```

**QGC识别逻辑**:
- QGC通过 `HEARTBEAT.type == MAV_TYPE_AIRSHIP` 识别飞艇
- 据此显示飞艇专属UI

### 3.2 模式映射 (PX4 nav_state → MAVLink custom_mode)

PX4使用 `vehicle_status.nav_state` (navigation state) 表示当前模式,通过 `px4_custom_mode` 转换为MAVLink `custom_mode`:

| PX4 nav_state | 飞艇模式(AirshipMode) | QGC显示名 | 备注 |
|--------------|---------------------|----------|------|
| NAVIGATION_STATE_MANUAL | Manual (0) | Manual | 手动输入姿态命令 |
| NAVIGATION_STATE_STAB | Stable (1) | Stabilized | 自动保持稳定 |
| NAVIGATION_STATE_ALTCTL | Altitude (2) | Altitude | 高度PID悬停 |
| NAVIGATION_STATE_POSCTL | Position (3) | Position | 位置PID控制 |
| NAVIGATION_STATE_OFFBOARD | Offboard (4) | Offboard | 外部控制 |
| NAVIGATION_STATE_AUTO_TAKEOFF | Takeoff (5) | Takeoff | 自动垂直爬升 |
| NAVIGATION_STATE_AUTO_LAND | Land (6) | Land | 自动垂直下降 |
| (Failsafe激活时) | Failsafe (7) | Failsafe | 失控保护 |
| NAVIGATION_STATE_AUTO_MISSION | Task (8) | Mission | 执行预设任务 |
| NAVIGATION_STATE_AUTO_LOITER | Altitude (2) | Loiter | 自动映射到Altitude |
| NAVIGATION_STATE_AUTO_RTL | Altitude (2) | RTL | 自动映射到Altitude |

**重要变更(相对v1.0文档)**:
- 旧文档: `Task=7`,错误
- 实际: `Failsafe=7, Task=8`
- AUTO_LOITER和AUTO_RTL在飞艇中映射到Altitude模式

### 3.3 QGC模式切换(发送给飞艇)

QGC通过 `MAV_CMD_DO_SET_MODE` 命令切换飞艇模式:
- `param1`: MAV_MODE_FLAG (含 CUSTOM_MODE_ENABLED)
- `param2`: main_mode (从 px4_custom_mode 解析)
- `param3`: sub_mode

**飞艇支持的main_mode**:
- `PX4_CUSTOM_MAIN_MODE_MANUAL` → Manual
- `PX4_CUSTOM_MAIN_MODE_STABILIZED` → Stable
- `PX4_CUSTOM_MAIN_MODE_ALTCTL` → Altitude
- `PX4_CUSTOM_MAIN_MODE_POSCTL` → Position
- `PX4_CUSTOM_MAIN_MODE_OFFBOARD` → Offboard
- `PX4_CUSTOM_MAIN_MODE_AUTO` + sub_mode:
  - `PX4_CUSTOM_SUB_MODE_AUTO_TAKEOFF` → Takeoff
  - `PX4_CUSTOM_SUB_MODE_AUTO_LAND` → Land
  - `PX4_CUSTOM_SUB_MODE_AUTO_MISSION` → Task
  - `PX4_CUSTOM_SUB_MODE_AUTO_LOITER` → Altitude(自动映射)
  - `PX4_CUSTOM_SUB_MODE_AUTO_RTL` → Altitude(自动映射)

---

## 4. Offboard控制接口

### 4.1 SET_ATTITUDE_TARGET消息(姿态+推力控制)

**消息ID**: `SET_ATTITUDE_TARGET` (#80)

**飞艇特殊处理** (代码位置: `src/modules/mavlink/mavlink_receiver.cpp` L1655-1669):

```c
// AIRSHIP: body_rate映射到thrust_body (pymavlink不支持thrust_body字段)
// body_roll_rate -> thrust_x(推进电机)
// body_pitch_rate -> thrust_y(原舵机tilt_angle, 新方案已弃用)
// 使用system_type判断: MAV_TYPE_AIRSHIP=7
if (vehicle_status.system_type == 7) {
    if (!(type_mask & ATTITUDE_TARGET_TYPEMASK_BODY_ROLL_RATE_IGNORE)) {
        attitude_setpoint.thrust_body[0] = attitude_target.body_roll_rate;
    }
    if (!(type_mask & ATTITUDE_TARGET_TYPEMASK_BODY_PITCH_RATE_IGNORE)) {
        attitude_setpoint.thrust_body[1] = attitude_target.body_pitch_rate;
    }
}
```

**飞艇Offboard控制字段映射**:

| MAVLink字段 | 飞艇控制量 | 范围 | 说明 |
|------------|----------|------|------|
| `q[4]` (四元数) | 姿态目标 | - | 仅pitch和yaw有效,roll不控制 |
| `body_roll_rate` | **Thrust X (推进)** | [-1, 1] | 推进电机前进推力 |
| `body_pitch_rate` | Thrust Y (已弃用) | [-1, 1] | 新方案无舵机,此字段无效 |
| `thrust` | **Thrust Z (升力)** | [0, 1] | 升力电机,经 `fill_thrust` 映射到 `thrust_body[2] = -thrust` |
| `thrust_body[3]` | 直接thrust_body | - | 备选方案,thrust_body字段直接使用 |

**type_mask位掩码**:
- `ATTITUDE_TARGET_TYPEMASK_ATTITUDE_IGNORE`: 忽略姿态(只用body_rate)
- `ATTITUDE_TARGET_TYPEMASK_BODY_ROLL_RATE_IGNORE`: 忽略body_roll_rate(不控制Thrust X)
- `ATTITUDE_TARGET_TYPEMASK_BODY_PITCH_RATE_IGNORE`: 忽略body_pitch_rate
- `ATTITUDE_TARGET_TYPEMASK_THROTTLE_IGNORE`: 忽略thrust(不控制Thrust Z)
- `ATTITUDE_TARGET_TYPEMASK_THRUST_BODY_SET`: 使用thrust_body[3]而非thrust

### 4.2 SET_POSITION_TARGET_LOCAL_NED消息(位置控制)

**消息ID**: `SET_POSITION_TARGET_LOCAL_NED` (#84)

飞艇处理逻辑与多旋翼相同,但仅使用:
- `x, y, z`: 本地NED位置目标
- `vx, vy, vz`: 速度目标
- `yaw`: 偏航角目标

**type_mask**: 栌准PX4位掩码

### 4.3 SET_POSITION_TARGET_GLOBAL_INT消息(全局位置控制)

**消息ID**: `SET_POSITION_TARGET_GLOBAL_INT` (#86)

使用经纬度+高度目标,适用于长距离导航。

---

## 5. 命令接口(MAVLink Commands)

### 5.1 起飞命令

**命令**: `MAV_CMD_NAV_TAKEOFF` (#22)

**飞艇处理逻辑**:
1. Commander收到命令 → 切换 `nav_state = NAVIGATION_STATE_AUTO_TAKEOFF`
2. AirshipControl检测到nav_state变化
3. **前置条件检查**: `alt_agl < AS_TAKEOFF_ALT` (高度必须低于起飞目标高度)
4. 检查通过 → 进入Takeoff模式,激活升力电机,推进电机关闭
5. 检查失败 → 拒绝起飞,PX4_WARN日志输出

**命令参数**:
- `param1`: pitch (飞艇忽略,使用AS_PIT_RMAX)
- `param4`: yaw (飞艇忽略)
- `param7`: altitude (飞艇忽略,使用AS_TAKEOFF_ALT)

### 5.2 降落命令

**命令**: `MAV_CMD_NAV_LAND` (#21)

**飞艇处理逻辑**:
1. Commander收到命令 → 切换 `nav_state = NAVIGATION_STATE_AUTO_LAND`
2. AirshipControl检测到nav_state变化 → 进入Land模式
3. 分阶段下降: VHI(>10m) → VMID(5-10m) → VLO(2-5m) → VGND(<2m)
4. 到达 `AS_LND_DONE_ALT` → 自动disarm

**命令参数**: 飞艇忽略所有参数,使用内部参数

### 5.3 航点命令

**命令**: `MAV_CMD_NAV_WAYPOINT` (#16)

飞艇在Task模式下执行预设任务航点,需考虑:
- 大惯量,提前规划减速
- 偏航受气动力矩限制,大角度转向需S形
- 起飞/降落航点必须垂直(无水平位移)

### 5.4 模式切换命令

**命令**: `MAV_CMD_DO_SET_MODE` (#176)

参考第3.3节"QGC模式切换"。

---

## 6. 状态遥测消息(PX4→QGC)

### 6.1 标准MAVLink遥测消息

| 消息 | ID | 飞艇字段说明 |
|------|----|---------|
| HEARTBEAT | #0 | type=7 (AIRSHIP), custom_mode=飞艇模式 |
| ATTITUDE | #30 | roll, pitch, yaw (rad) |
| LOCAL_POSITION_NED | #32 | x, y, z, vx, vy, vz (NED) |
| GLOBAL_POSITION_INT | #33 | lat, lon, alt, relative_alt |
| ALTITUDE | #141 | altitude_monotonic, altitude_local, altitude_relative |
| VFR_HUD | #74 | airspeed, groundspeed, heading, throttle |
| SYS_STATUS | #1 | 电池、GPS、传感器状态 |
| GPS_RAW_INT | #24 | GPS原始数据 |
| BATTERY_STATUS | #147 | 电池详细状态 |
| NAV_CONTROLLER_OUTPUT | #62 | 导航控制器输出 |
| MISSION_CURRENT | #42 | 当前任务航点 |
| COMMAND_ACK | #77 | 命令确认 |
| TAKEOFF_STATUS | #195 | 起飞状态(飞艇发布) |

### 6.2 自定义流(QGC可订阅)

飞艇通过 `AVAILABLE_MODES` (#435) 和 `CURRENT_MODE` (#436) 消息宣告支持的飞行模式。

---

## 7. 参数传输接口

### 7.1 参数同步流程

```
QGC请求参数列表 → MAVLink PARAM_REQUEST_LIST → PX4遍历所有参数
                                                ↓
PX4发送 PARAM_VALUE ← (循环发送所有参数) ← PX4
                                                ↓
QGC收到 PARAM_VALUE → 更新参数UI显示

QGC修改参数 → MAVLink PARAM_SET → PX4更新参数 → PX4发送 PARAM_VALUE(新值) → QGC
```

### 7.2 参数消息

| 消息 | ID | 用途 |
|------|----|------|
| PARAM_REQUEST_LIST | #21 | QGC请求所有参数 |
| PARAM_REQUEST_READ | #20 | QGC请求单个参数 |
| PARAM_VALUE | #22 | PX4发送参数值 |
| PARAM_SET | #23 | QGC设置参数值 |

### 7.3 飞艇参数特性

- 所有 `AS_*` 和 `BALLOON_*/BLOWER_*/VALVE_*/TRIM_BALLOON_*` 参数都通过MAVLink同步
- 参数分组通过 `@group` 标签(QGC自动解析)
- 参数范围通过 `@min/@max` 标签
- 参数单位通过 `@unit` 标签
- 参数精度通过 `@decimal` 标签

---

## 8. Companion Computer接口

### 8.1 以太网接口

- 端口: Ethernet (MAV_2_CONFIG=1000)
- 速率: 100kB/s (MAV_2_RATE=100000)
- UDP端口: 14550 (MAV_2_UDP_PRT)
- 远程端口: 14550 (MAV_2_REMOTE_PRT)
- 模式: Custom (MAV_2_MODE=0)

### 8.2 UXRCE-DDS接口(可选,ROS2)

- 通过 `UXRCE_DDS_CFG` 参数配置
- 用于Companion Computer通过ROS2通信

### 8.3 Companion Computer用途

- 视觉定位
- 路径规划
- 避障
- 高级任务编排
- 通过Offboard模式发送setpoint
