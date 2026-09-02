# 03 - uORB消息与MAVLink接口

**文档版本**: 3.0 (基于2026-08-30全量代码分析, V2架构)
**最后更新**: 2026-08-30

## 1. 自定义uORB消息

### 1.1 airship_altitude_setpoint.msg (飞艇目标高度) — V2新增

**文件**: `msg/airship_altitude_setpoint.msg`

```c
uint64 timestamp
# 由 airship_att_control 发布, ballast_control 订阅用于独立浮力PID调节
float32 target_altitude   # 目标高度 (NED z, 负值=高度, 单位m)
```

**发布时机** (AirshipControl.cpp): 每次`vehicle_angular_velocity`回调驱动runControl后, 若目标有效则发布。
**目标来源**: ①`DO_CHANGE_ALTITUDE`命令 ②Takeoff模式起飞目标(守卫: 目标无效或残留地面AGL<1m时强制设为起飞目标, 防止ballast误充气把艇压在地面) ③Task模式航点z同步 ④Altitude/Position模式任务activate后回写。切模式时故意不重置。

### 1.2 ballast_setpoint.msg (浮力调节设定值) — V2扩展

**文件**: `msg/ballast_setpoint.msg`

```c
uint64 timestamp
float32 net_buoyancy      # 净浮力调整量 (N), 正=上升, 负=下降
float32 blower_left       # 旧字段, 保留兼容(发布端不填充)
float32 blower_right      # 旧字段, 保留兼容
float32 valve_left        # 旧字段, 保留兼容
float32 valve_right       # 旧字段, 保留兼容
float32 altitude_error    # 当前高度误差 (m)
float32[4] ballast_mass   # 四囊空气质量(kg), 0=左主 1=右主 2=左副 3=右副 (四囊同步, 同一值)
uint8[4]  ballast_blower  # 风机占空比 0~255 (0=停, >0=运行, 严禁按位与解读)
uint8[4]  ballast_valve   # 阀门命令 0=关 / 255=开 (常闭阀)
```

**消息流向**:
```
ballast_control (发布) → ballast_setpoint → ballast_output (实飞PWM)
                                           → GZMixingInterfaceBallast (仿真GZ, 10Hz)
```
**此消息不通过MAVLink发送到QGC。** QGC监控浮力系统用NAMED_VALUE_FLOAT(见第5节)。

### 1.3 takeoff_status (标准消息, 飞艇接管发布)

AirshipControl每周期发布: 未解锁→DISARMED(1); landed→READY_FOR_TAKEOFF(3); 否则→FLIGHT(5); `tilt_limit=1.0`。
**目的**: 防止flight_mode_manager反复reActivate FlightTask。**纯uORB, 默认不发MAVLink**, QGC无法直接读取, 只能靠HEARTBEAT子模式推断。

---

## 2. airship_att_control 订阅/发布话题

### 2.1 订阅

| 话题 | 用途 |
|------|------|
| vehicle_angular_velocity | **回调驱动源**(IMU频率, Run()节拍) |
| vehicle_status | nav_state/arming_state/failsafe |
| manual_control_setpoint | 摇杆输入 |
| vehicle_attitude / vehicle_local_position | 状态反馈 |
| vehicle_attitude_setpoint | Offboard输入(500ms新鲜度) |
| vehicle_control_mode / offboard_control_mode | 控制模式 |
| vehicle_land_detected | 着陆状态 |
| trajectory_setpoint | Position模式目标注入(仅pos[0/1], **不用pos[2]**防掉高度) |
| position_setpoint_triplet | Task模式航点(MapProjection换算lat/lon→本地NED) |
| failsafe_flags | RC/GCS链路状态 |
| wind | EKF2风速(Position模式调试) |
| parameter_update | 参数热更新 |
| vehicle_command | NAV_TAKEOFF(param7改起飞高度)/NAV_LAND/DO_CHANGE_ALTITUDE |

### 2.2 发布

| 话题 | 字段含义 |
|------|---------|
| vehicle_thrust_setpoint | xyz[0]=前进推力[0,1], xyz[1]=**恒0**(侧向不用), xyz[2]=垂直推力[-1,1] **负=上升/正=下降** |
| vehicle_torque_setpoint | xyz[0]=横滚(上升电机左右差动), xyz[1]=俯仰(含Munk前馈), xyz[2]=偏航(Takeoff/Land强制0) |
| vehicle_command | ①起飞完成: `DO_SET_MODE`(AUTO+LOITER) ②降落完成: `COMPONENT_ARM_DISARM`(param2=21196强制) |
| takeoff_status | 见1.3 |
| airship_altitude_setpoint | 见1.1 |

**下游**: thrust/torque setpoint → `ActuatorEffectivenessCustom`(手工分配) → actuator_motors(10电机)。

---

## 3. MAV_TYPE_AIRSHIP 全链路

PX4内核对飞艇的唯一身份认定: `commander_helper.cpp:is_rotary_wing()` 把 AIRSHIP 归入旋翼 → `vehicle_type = VEHICLE_TYPE_ROTARY_WING`。带来的影响:

| 影响 | 说明 |
|------|------|
| MANUAL模式自动带姿态增稳 | stabilization_required()=true |
| **AUTO_TAKEOFF要求完整local_position** | 旋翼专属要求(固定翼只需relaxed); GPS未收敛时解锁状态下TAKEOFF被拒 |
| takeoff走旋翼分支 | navigator/takeoff.cpp |

MAV_TYPE_AIRSHIP代码位置:
- `mavlink_receiver.cpp:1581` fill_thrust: AIRSHIP与多旋翼同case, `thrust_body[2] = -thrust`
- `mavlink_receiver.cpp:1658-1669` SET_ATTITUDE_TARGET: `system_type==7` 时 body_roll_rate→thrust_body[0]、body_pitch_rate→thrust_body[1]
- `commander_helper.cpp:98` is_rotary_wing含AIRSHIP
- `Commander.cpp:1741-1744` MAV_TYPE参数→system_type
- `mode_requirements.cpp:170-173` 旋翼AUTO_TAKEOFF需完整local_position

---

## 4. 模式映射与HEARTBEAT

**custom_mode生成**: `get_px4_custom_mode(nav_state)` 纯标准实现, 无飞艇特殊分支。AirshipMode内部枚举**不出现在任何MAVLink消息**, QGC靠nav_state推断。

| AirshipMode(内部) | nav_state | custom_mode(main,sub) | QGC显示 |
|-------------------|-----------|----------------------|---------|
| Manual=0 | MANUAL | (1 MANUAL, 0) | Manual |
| Stable=1 | STAB | (7 STABILIZED, 0) | Stabilized |
| Altitude=2 | ALTCTL | (2 ALTCTL, 0) | Altitude |
| Position=3 | POSCTL | (3 POSCTL, 0) | Position |
| Offboard=4 | OFFBOARD | (6 OFFBOARD, 0) | Offboard |
| Takeoff=5 | AUTO_TAKEOFF | (4 AUTO, 2 TAKEOFF) | Takeoff子模式 |
| Land=6 | AUTO_LAND | (4 AUTO, 6 LAND) | Land子模式 |
| Failsafe=7 | 跟随failsafe动作 | (4 AUTO, 3 LOITER)等 | — |
| Task=8 | AUTO_MISSION | (4 AUTO, 4 MISSION) | Mission |
| **PropTest=9** | **ACRO** | (5 ACRO, 0) | Acro (**V2新增: 单侧推进测试, 需CA_AS_PT_EN=1**) |
| — | AUTO_LOITER | (4 AUTO, 3 LOITER) | Loiter (飞艇=Altitude悬停) |
| — | AUTO_RTL | (4 AUTO, 5 RTL) | RTL (**飞艇实际=Altitude原地悬停, 不飞回home**) |

**模式切换(DO_SET_MODE)处理链**: QGC → mavlink_receiver原样转发 → Commander.handle_command解析main/sub → UserModeIntention.change(已解锁时过canRun健康检查, POSCTL可降级ALTCTL)。
**特殊**: NAV_LAND **force=true总是可切入**(紧急模式); AUTO_TAKEOFF无force, 受canRun约束(需local_position)。
被拒时QGC收到: `COMMAND_ACK: TEMPORARILY_REJECTED` + STATUSTEXT "Switching to %s is currently not available"。

---

## 5. 浮力系统QGC可见性(NAMED_VALUE_FLOAT)

ballast_control通过 `debug_key_value` 轮转发布5个字段 → MAVLink **NAMED_VALUE_FLOAT** 消息 → QGC的 **MAVLink Inspector** 可直接查看:

| key | 含义 | 单位 |
|-----|------|------|
| buoy | 净浮力调整量 | N |
| alt_err | 高度误差 | m |
| b_mass | 单囊空气质量 | kg |
| blower | 风机占空比 | 0-255 |
| valve | 阀门状态 | 0/255 |

每字段更新约10Hz(50Hz/5字段轮转)。QGC可基于此做浮力仪表盘。

---

## 6. Offboard控制接口

### 6.1 SET_ATTITUDE_TARGET (#80) — 飞艇字段映射

```c
// mavlink_receiver.cpp:1658-1669, system_type==7时:
if (!(type_mask & BODY_ROLL_RATE_IGNORE))  attitude_setpoint.thrust_body[0] = body_roll_rate;   // → 推进电机thrust_x
if (!(type_mask & BODY_PITCH_RATE_IGNORE)) attitude_setpoint.thrust_body[1] = body_pitch_rate;  // → tilt通道(任务层已废弃忽略)
```

| MAVLink字段 | 飞艇控制量 | 范围 | 任务层处理(AirshipTaskOffboard) |
|------------|----------|------|------|
| `q[4]` | 姿态目标 | - | pitch限±15°, yaw取psi |
| `body_roll_rate` | **Thrust X(推进)** | [0,1]有效 | thrust_x=constrain(val,0,1) |
| `body_pitch_rate` | Thrust Y | - | **tilt_angle已废弃, 忽略** |
| `thrust` | Thrust Z(升力) | [-1,1] | fill_thrust映射thrust_body[2]=-thrust → velocity(2) |
| `thrust_body[3]` | 直接透传 | - | thrust_body分支 |

**无效时安全行为**: 500ms无新鲜setpoint → thrust_x=0, velocity(2)=0(安全悬停)。

### 6.2 SET_POSITION_TARGET_LOCAL_NED (#84) / GLOBAL_INT (#86)

标准处理: position/velocity/yaw字段, 经trajectory_setpoint进入Task/Position链路。
**注意**: 飞艇Position模式不使用trajectory_setpoint.position[2](标准PX4会置0导致掉高度), 高度走airship内部altitude_target链。

### 6.3 Offboard进入条件

1. 上位机持续流式发送setpoint(每条消息重发offboard_control_mode打时间戳)
2. offboard信号有效: 1秒内(COM_OF_LOSS_T)有任一setpoint流
3. DO_SET_MODE(6 OFFBOARD)切入; 已解锁时需canRun(要求angular_velocity+attitude+offboard_signal)
4. MAV_FWDEXTSP=1(转发使能)

---

## 7. 命令接口(MAVLink Commands)

| 命令 | ID | 飞艇处理 |
|------|----|---------|
| MAV_CMD_NAV_TAKEOFF | 22 | Commander切nav_state=AUTO_TAKEOFF(**无landed/高度检查, 但已解锁需canRun: 完整local_position**); AirshipControl前置检查 `alt_agl < AS_TAKEOFF_ALT`, 超高则PX4_WARN拒绝(**不发STATUSTEXT, QGC看不到拒绝原因**); param7>1m时覆盖起飞目标高度 |
| MAV_CMD_NAV_LAND | 21 | **force=true总是可切入**; AirshipControl分阶段下降; 完成后自动强制DISARM |
| MAV_CMD_NAV_WAYPOINT | 16 | Task模式标准航点; **LOITER占位航点特殊处理**: current==LOITER且next==POSITION时直接取next(中性浮力不先爬升再水平) |
| MAV_CMD_DO_CHANGE_ALTITUDE | 178 | **支持**: param1(AGL)→全局altitude_target(同步给ballast) |
| MAV_CMD_DO_SET_MODE | 176 | 标准模式切换 |
| MAV_CMD_COMPONENT_ARM_DISARM | 400 | 降落完成时AirshipControl自动发(param2=21196强制) |

---

## 8. 状态遥测消息(PX4→QGC)

| 消息 | ID | 飞艇要点 |
|------|----|---------|
| HEARTBEAT | #0 | type=7; base_mode含ARMED/_MANUAL_INPUT/_STABILIZE/_AUTO位; system_status: failsafe时CRITICAL |
| EXTENDED_SYS_STATE | #245 | landed_state(经vehicle_land_detected) |
| ATTITUDE/LOCAL_POSITION_NED/GLOBAL_POSITION_INT/ALTITUDE/VFR_HUD | 标准 | — |
| ACTUATOR_OUTPUT_STATUS / SERVO_OUTPUT_RAW | #25/#14 | 10电机输出(esc_rpm实为归一化motor_speed非真实RPM) |
| NAMED_VALUE_FLOAT | #295 | **浮力系统5字段轮转**(见第5节) |
| COMMAND_ACK | #77 | 模式拒绝等 |
| AVAILABLE_MODES/CURRENT_MODE | #435/#436 | 模式列表与intended mode |

---

## 9. 参数传输

标准PARAM_REQUEST_LIST/PARAM_REQUEST_READ/PARAM_VALUE/PARAM_SET流程。所有`AS_*`/`BALLOON_*`/`CA_AS_*`/`LNDAS_*`均同步; @group/@min/@max/@unit/@decimal标签QGC自动解析。

---

## 10. Companion Computer接口

- Ethernet: MAV_2_CONFIG=1000, MAV_2_MODE=0(Custom), MAV_2_RATE=100000, UDP 14550
- UXRCE-DDS(可选): UXRCE_DDS_CFG配置, ROS2通信
- 用途: 视觉定位/路径规划/避障/Offboard setpoint
