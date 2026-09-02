# 04 - 飞行模式与状态机

**文档版本**: 3.0 (基于2026-08-30全量代码分析, V2架构)
**最后更新**: 2026-08-30

## 1. AirshipMode枚举

**代码位置**: `src/modules/airship_att_control/AirshipControl.hpp` L46-59

```cpp
enum class AirshipMode : uint8_t {
    Manual    = 0,
    Stable    = 1,
    Altitude  = 2,
    Position  = 3,
    Offboard  = 4,
    Takeoff   = 5,
    Land      = 6,
    Failsafe  = 7,
    Task      = 8,
    PropTest  = 9,   // V2新增: ACRO模式单侧推进测试
};
```

**重要**: 此枚举是airship_att_control内部状态机, **不出现在任何MAVLink消息中**。QGC只能通过HEARTBEAT的nav_state映射(custom_mode)推断, PropTest对应PX4标准ACRO模式(5)。

## 2. detectMode()完整优先级 (AirshipControl.cpp L328-438)

| 优先级 | 条件 | 返回模式 |
|---|---|---|
| 1 | `_failsafe_active` | **Failsafe** |
| 2 | nav_state==AUTO_MISSION | **Task** (用户意图优先, 起飞Hold期间切MISSION不会卡Takeoff) |
| 2 | nav_state==ACRO | **PropTest** (需CA_AS_PT_EN=1才有实际效果) |
| 2 | AUTO_TAKEOFF + `_takeoff_completed` | `_mode_override`(≠Manual) 否则 **Altitude** |
| 2 | AUTO_TAKEOFF + z有效且 `-z >= AS_TAKEOFF_ALT` | **Altitude** (V3修复: 高于目标不激活Takeoff, 防Settle失控下落) |
| 2 | AUTO_TAKEOFF (其余) | **Takeoff** |
| 2 | AUTO_LAND | **Land** |
| 2 | AUTO_LOITER + 起飞进行中(`_takeoff_requested && !completed`) | **Takeoff** (V2: Navigator提前切LOITER需继续爬升) |
| 2 | AUTO_LOITER (其余) | **Altitude** |
| 2 | AUTO_RTL | 同LOITER逻辑 → **Takeoff** 或 **Altitude** (**RTL对飞艇=原地定高悬停, 不飞回home**) |
| 3 | `_takeoff_requested && !completed` | **Takeoff** (nav_state已切走的过渡期) |
| 3 | `_land_requested` | **Land** |
| 4 | `_mode_override != Manual` | `_mode_override` |
| 5 | MANUAL/STAB/ALTCTL/POSCTL/OFFBOARD | Manual/Stable/Altitude/Position/Offboard |
| 6 | control_mode标志兜底 | Offboard/Position/Altitude/Stable |
| 7 | 默认 | **Manual** |

**_mode_override机制**: 唯一设置点=起飞完成→Altitude; 用户/Commander任何显式模式切换都清除; 作用是起飞完成到Commander处理DO_SET_MODE之间的过渡窗口保持Altitude。

## 3. 各模式状态机详解

### 3.1 Takeoff (起飞, =5) — 核心状态机

```
Settle(0) → Climb(1) → Hold(2) → Complete(3)
```

| 阶段 | 时长/条件 | 行为 |
|------|----------|------|
| **Settle** | 激活后0-5s | 保持当前高度(position(2)=当前z), 水平=当前位置, thrust_x=0; 等待EKF z初始化 |
| **Climb** | Settle结束→到达目标 | position(2)=target_z(**绝对AGL的NED负值**, V3修复), AS_TKF_VMAX=0.5m/s限速, AS_TAKEOFF_RAMP=5s推力软启动(重置高度积分器), 推进电机关闭 |
| **Hold** | 到达后 | \|pos_z - target_z\| <= AS_TKF_ALT_TOL(2m)内连续计时; 超差重置; 连续 >= AS_TKF_HOLD_T(20s) → Complete |
| **Complete** | - | runControl发`DO_SET_MODE(AUTO+LOITER)` + `_mode_override=Altitude` + `_takeoff_completed=true`; 日志`[TAKEOFF] Completed -> switching to AUTO_LOITER` |

- **cancel()**: 模式切换/AUTO_LAND时置cancelled, 提前完成退出
- **落地复位**: `_takeoff_completed && landed && alt_agl<1m` → 清takeoff状态
- **手动油门爬升**: Climb阶段setManualThrottle可调velocity(2), 但当前代码position三分量均finite走updatePosition分支, **该velocity(2)实际不生效**(已知问题)

### 3.2 Land (降落, =6)

```
PoweredDescent(0) → Done(1)
```

- **分阶段下降速度** (computeDescentVelocity): >10m→AS_LND_VHI(1.5); 5-10m→VMID(1.0); 2-5m→VLO(0.5); <2m→VGND(0.2) m/s
- **实现**: position(2)=NAN + velocity(2)=下降速度 + position(0/1)=当前位置 → 走"水平位置PID+垂直速度PID"分支(复用高度积分器)
- **Done判据**: `alt_agl <= AS_LND_DONE_ALT(3m)`, **不依赖landed标志**(中性浮力悬停landed=true会误触发)
- **Done动作**: velocity(2)=0悬停 → runControl发`VEHICLE_CMD_COMPONENT_ARM_DISARM`(param2=21196强制) → QGC显示已解锁
- **AUTO_LAND模式强制landed=true**(land_detector配合语义)

### 3.3 Failsafe (故障保护, =7) — 内部机制

**触发** (checkFailsafe, 独立于Commander failsafe状态机):
- 条件: ARMED + (RC丢失 **或** GCS丢失, 任一即可, V2修复) + 此前收到过正常心跳 + 心跳超时5s
- 动作: `_failsafe_active=true`, detectMode→Failsafe, 任务=锁定当前位置/高度/yaw安全悬停
- **Failsafe任务细节(V6)**: 位置有效→锁定xy但不设thrust_x(让L1导引纠漂移); yaw不写setpoint(让位置PID的yaw_setpoint指向误差方向); 无估计时velocity=0+thrust_x=0靠中性浮力悬停
- **解除**: 信号恢复即解除(日志`[FAILSAFE] Signal recovered`) 或 解锁
- **QGC可见性限制**: 仅console日志`[FAILSAFE] === ACTIVATED ===`, **不发STATUSTEXT**, QGC界面无告警

**与Commander failsafe的关系**: 两套并行。Commander层(RC/DLL丢失按NAV_RCL_ACT/NAV_DLL_ACT=3→RTL, 飞艇RTL实际被detectMode降维成Altitude悬停); AirshipControl内部层(锁定悬停)。实飞表现: 信号丢失时ballast_control还会触发紧急排气。

### 3.4 PropTest (推进测试, =9, ACRO模式)

- ACRO模式 + ARMED + CA_AS_PT_EN=1 → 控制分配器旁路全部闭环
- 仅输出CA_AS_PT_SIDE指定一侧推进电机(0=左组M6+M8, 1=右组M7+M9, 2=仅M6, 3=仅M7, 4=仅M0诊断), 油门=CA_AS_PT_THR(0.3)
- 用途: 复现/量化单侧推进引发的姿态耦合失控
- DISARM立即全零

### 3.5 Manual (手动, =0)

无状态机, 直接映射: thrust_x=constrain(throttle,0,1); yawspeed=roll_stick*YAW_RMAX; pitch=pitch_stick*15°; velocity(2)=-pitch_stick*ALT_SRATE(**pitch杆双职能: 同时控俯仰角和升降**, 升降走速度直通)。
**注**: PX4内核把飞艇归旋翼, MANUAL本身带姿态增稳。

### 3.6 Stable (自稳定, =1)

yaw锁定(activate时记当前yaw)+俯仰角控制: thrust_x=throttle; velocity(2)=pitch_stick(±1); yawspeed=roll_stick; **pitch=yaw_stick*15°**(yaw杆控俯仰)。悬停检测: thrust_x<0.01且无torque_z时推进关闭。

### 3.7 Altitude (定高, =2)

- activate: 锁当前高度为目标
- 摇杆调高: 油门偏离中位(死区0.05) → 目标±AS_ALT_SRATE*dt; **外部目标注入**(DO_CHANGE_ALTITUDE/起飞残留)时禁用摇杆调高
- 悬停转向(P7): roll_stick>0.05且forward<0.06时自动给最小forward=0.06(仅用户主动输入触发, 与分配器yaw_diff需要forward>0.05配合)
- 高度三级限位见02_parameters第1节

### 3.8 Position (定点, =3)

- activate: 锁当前位置+高度
- 摇杆: 速度指令(vx=pitch_stick*vel_max, vy=-roll_stick*vel_max)经yaw旋转积分移动目标点; 油门调高
- 目标注入: trajectory_setpoint pos[0/1](500ms新鲜度, **不用pos[2]**), 高度走内部链
- L1导引+停推保护见02_parameters第5节
- 1Hz调试日志`[POSDBG]`(风速/漂移/误差/输出)

### 3.9 Offboard (外部控制, =4)

输入vehicle_attitude_setpoint(500ms新鲜): thrust_body[0]→thrust_x, thrust_body[2]→thrust_z, q_d→pitch(±15°)/yaw。无效时安全悬停。

### 3.10 Task (任务, =8)

- 目标来自position_setpoint_triplet: MapProjection把lat/lon投成本地NED, target_z=-(alt-ref_alt)
- **LOITER占位处理**: current==LOITER且next==POSITION时直接取next(飞艇中性浮力不做"先爬升再水平", 否则原地LOITER永不前进)
- 航点高度同步到全局altitude_target(供ballast)
- triplet无效→holdPosition回锁当前位置
- yaw优先用triplet的yaw_target

## 4. 模式间自动切换行为汇总

| 事件 | 自动行为 | QGC看到的现象 |
|------|---------|--------------|
| 起飞完成(Hold 20s) | 发DO_SET_MODE(AUTO+LOITER) | 模式显示从Takeoff变Loiter |
| 降落完成(alt<=3m) | 发强制DISARM(21196) | 显示Disarmed |
| 起飞中Navigator切LOITER | detectMode保持Takeoff(内部标志) | 显示Loiter但仍在爬升 |
| RC/GCS丢失(实飞NAV_RCL/DLL_ACT=3) | Commander→AUTO_RTL→飞艇Altitude悬停 + ballast紧急排气 | 显示RTL/Loiter, 高度缓慢变化 |
| 信号恢复 | 内部failsafe解除, 回detectMode自然结果 | 恢复正常 |
| Takeoff请求但alt>=20m | PX4_WARN拒绝, 保持Altitude | **无任何QGC提示(仅日志)** |

## 5. 模式与执行器激活映射(V2)

| 模式 | 上升电机0-3 | 下降电机4-5 | 推进电机6-9 | 浮力系统 |
|------|------------|------------|------------|---------|
| Manual/Stable/Altitude/Position/Offboard/Task | 按thrust_z/torque | 按thrust_z/torque | 按**nav_state硬开关**(非起降模式允许), 可反转差动 | 独立PID |
| **Takeoff/Land** | 激活 | 激活 | **强制关闭**(`_prop_allowed=false`, nav_state级硬开关) | 独立PID |
| Failsafe | 锁定悬停输出 | — | L1导引或0 | **紧急排气**(若failsafe) |
| PropTest(ACRO) | 仅PT_SIDE=4时M0 | 关 | 仅指定单侧 | 独立PID |

**关键**: 起飞/降落推进关闭的判定已从"thrust_x<0.01启发式"升级为**nav_state硬开关**(ActuatorEffectivenessCustom L184-200), 同时保留`takeoff_hover_mode=(thrust_x<0.01 && |torque_z|<0.01)`判定用于悬停工况。
