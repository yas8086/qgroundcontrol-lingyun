# 06 - QGC开发要点

## 1. 飞艇识别

### 1.1 识别逻辑

QGC通过 MAVLink `HEARTBEAT.type == MAV_TYPE_AIRSHIP (7)` 识别飞艇。

**关键代码位置**:
- `src/modules/mavlink/mavlink_receiver.cpp` - MAVLink消息处理
- `src/modules/commander/Commander.cpp` - 飞行模式管理

**QGC识别后应启用**:
- 飞艇专属UI(虚拟摇杆映射、模式按钮)
- 飞艇参数页面
- 飞艇HUD元素

### 1.2 QGC参数检查

QGC需要检查的飞艇标识:
- `MAV_TYPE = 7` (MAV_TYPE_AIRSHIP)
- airframe配置正确(2058_lingyun01)

---

## 2. 飞行模式显示

### 2.1 模式按钮显示

QGC需要为飞艇显示以下模式按钮(按常用顺序):

| 模式按钮 | custom_mode映射 | 显示文本 | 启用条件 |
|---------|----------------|---------|---------|
| Manual | MAIN_MODE_MANUAL | "Manual" | 始终启用 |
| Stabilized | MAIN_MODE_STABILIZED | "Stabilized" | 始终启用 |
| Altitude | MAIN_MODE_ALTCTL | "Altitude" | 始终启用 |
| Position | MAIN_MODE_POSCTL | "Position" | GPS锁定 |
| Offboard | MAIN_MODE_OFFBOARD | "Offboard" | offboard_control_mode有效 |
| Takeoff | MAIN_MODE_AUTO + SUB_TAKEOFF | "Takeoff" | ARMED + alt<20m |
| Land | MAIN_MODE_AUTO + SUB_LAND | "Land" | ARMED |
| Mission | MAIN_MODE_AUTO + SUB_MISSION | "Mission" | 任务已上传 |

### 2.2 特殊状态指示

**起飞模式特殊显示**:
- 显示"起飞中" + 目标高度
- 起飞完成后自动切换到Altitude显示
- 显示起飞进度(Climb/Hold阶段)

**降落模式特殊显示**:
- 显示"降落中" + 当前下降速度
- 显示分阶段下降状态(VHI/VMID/VLO/VGND)
- 显示降落到Done高度的剩余距离

**悬停状态显示**:
- 中性浮力状态(推力=0时显示"浮力平衡")
- 推进电机关闭指示

**Failsafe状态显示**:
- 显示触发源(RC丢失/数据链丢失/低电量)
- 显示动作(返航/降落)
- 显示剩余超时时间

---

## 3. 参数界面定制

### 3.1 建议参数页面结构

**页面1: 飞艇姿态控制 (AS_* 参数)**

子组1: 高度PID
- AS_ALT_P, AS_ALT_I, AS_ALT_D, AS_ALT_IMAX, AS_ALT_VMAX, AS_ALT_VFF
- AS_ALT_MAX, AS_ALT_MIN, AS_ALT_SOFT, AS_ALT_SRATE

子组2: 俯仰PID
- AS_PIT_P, AS_PIT_I, AS_PIT_IMAX
- AS_PR_P, AS_PR_I, AS_PR_D, AS_PR_IMAX
- AS_PIT_RMAX, AS_PIT_FF

子组3: 偏航PID
- AS_YAW_P, AS_YAW_I, AS_YAW_IMAX
- AS_YR_P, AS_YR_I, AS_YR_D, AS_YR_IMAX
- AS_YAW_RMAX, AS_YAW_TMAX

子组4: 起飞/降落
- AS_TAKEOFF_ALT, AS_TKF_HOLD_T, AS_TKF_ALT_TOL, AS_TAKEOFF_RAMP
- AS_LND_DONE_ALT, AS_LND_VHI, AS_LND_VMID, AS_LND_VLO, AS_LND_VGND

子组5: 位置/速度PID
- AS_POS_XY_P, AS_POS_XY_MAX
- AS_VEL_XY_P, AS_VEL_XY_I, AS_VEL_XY_D, AS_VEL_XY_IMAX, AS_VEL_XY_MAX

子组6: 自动测试/调参(高级)
- AS_TST_EN, AS_TST_PIT, AS_TST_YAW
- AS_AT_EN, AS_AT_AMP, AS_AT_DUR

**页面2: 浮力控制 (BALLOON_* 参数)**

子组1: 浮力辅助控制
- BALLOON_AST_EN, BALLOON_DEADZONE, BALLOON_THRSHLD
- BALLOON_P_GAIN, BALLOON_I_GAIN, BALLOON_D_GAIN, BALLOON_I_MAX
- BALLOON_RATE_MAX

子组2: 横滚主动控制 (四气囊, 已验证)
- BALLOON_R_EN, BALLOON_R_P, BALLOON_R_I, BALLOON_R_IMX
- BALLOON_RR_P, BALLOON_RR_D, BALLOON_R_MAX
- BALLOON_M_MAX, BLWR_FLOW, VALVE_HYST, VALVE_MIN_T

子组3: 鼓风机/阀门
- BLOWER_TAU, VALVE_OPEN_DELAY

子组4: 配平
- TRIM_BALLOON_EN, TRIM_BALLOON_P, TRIM_BALLOON_I, TRIM_BALLOON_IMX

**页面3: 控制分配 (CA_* 参数,只读)**

子组1: 物理常数
- CA_AS_K_LUP, CA_AS_K_LDN, CA_AS_K_PROP
- CA_AS_PZ_PROP, CA_AS_PX_FRONT, CA_AS_PX_REAR

子组2: 电机配置
- CA_ROTOR0-7的PX/PY/PZ/AX/AY/AZ/CT/KM

**页面4: 安全限制**

子组1: 高度限位
- AS_ALT_MAX (最大高度)
- AS_ALT_MIN (最小高度)
- AS_ALT_SOFT (软限位)

子组2: 速度限制
- AS_VEL_XY_MAX
- AS_ALT_VMAX
- MPC_XY_VEL_MAX, MPC_Z_VEL_MAX_UP, MPC_Z_VEL_MAX_DN

子组3: 浮力调节速率
- BALLOON_RATE_MAX

子组4: Failsafe
- NAV_RCL_ACT, COM_RC_LOSS_T
- NAV_DLL_ACT, COM_DL_LOSS_T
- COM_LOW_BAT_ACT, COM_FAIL_ACT_T

### 3.2 参数预设(场景化)

QGC建议提供"参数预设"按钮:

**预设1: 仿真调试** (加载 rc.lingyun01_defaults 值)
- 完整PID增益
- 禁用所有failsafe
- 允许无GPS解锁

**预设2: 实飞首飞** (加载 2058_lingyun01 值)
- PID增益减半
- 启用所有failsafe
- 必须GPS解锁
- 限速减半

**预设3: 实飞调试** (首飞后根据响应调整)
- 基于首飞数据手动调整

---

## 4. 自定义HUD元素

### 4.1 建议HUD指示器

**主HUD**:
- 高度(AGL) - 大字号显示
- 水平速度 - 矢量显示
- 偏航角 - 数字+罗盘
- 俯仰角 - 姿态指示器
- 当前模式 - 文本+图标
- 解锁状态 - ARM/DISARM
- GPS状态 - 卫星数+HDOP
- 电池状态 - 电压+电流+剩余百分比

**飞艇专属HUD**:

| 指示器 | 显示内容 | 数据来源 |
|--------|---------|---------|
| 净浮力指示器 | 当前浮力状态(正/负/平衡) | 从ALTITUDE高度误差推断 |
| 四气囊横滚控制状态 | 横滚角+力矩需求+各气囊质量 | ATTITUDE.roll (横滚控制内部状态无MAVLink) |
| 左右浮力差 | 横滚偏差指示(目标0deg) | ATTITUDE.roll |
| 推进电机抬头补偿 | 补偿状态(激活/未激活) | 从VFR_HUD.throttle推断 |
| 推进电机关闭指示 | "推进电机:OFF" | 起飞/降落模式时 |
| 升力电机分组指示 | M0/M3上升或M1/M2下降 | 从模式推断 |
| 起飞进度 | Climb/Hold + 进度 | TAKEOFF_STATUS消息 |
| 降落阶段 | VHI/VMID/VLO/VGND | 从ALTITUDE推断 |
| Failsafe状态 | 触发源+动作+剩余时间 | SYS_STATUS + 内部计算 |

**横滚控制专属显示** (已验证: 稳态<1deg):
- 当前横滚角 (deg, 目标0deg)
- 横滚力矩需求 (roll_moment_demand, [-1,1])
- 四气囊空气质量分布 (LI/LO/RI/RO, kg)
- 横滚控制状态 (启用/禁用, 由BALLOON_R_EN决定)

### 4.2 警告提示

**关键警告**:
- 高度接近硬限位(AS_ALT_MAX)
- 高度接近硬下限(AS_ALT_MIN)
- 偏航角偏差过大(>15°)
- 俯仰角偏差过大(>10°)
- 推进电机在起飞/降落模式激活(异常)
- Failsafe触发
- GPS信号弱
- 数据链信号弱
- 电池低电量
- 浮力调节系统故障(假设有故障检测)

---

## 5. 任务规划特殊处理

### 5.1 飞艇任务特点

- 起飞任务: 只能设置高度(垂直爬升),不能设置水平位移
- 航点任务: 需考虑大惯量,提前规划减速
- 降落任务: 需设置降落区域(考虑漂移)
- 偏航转向: 大角度转向需S形(气动力矩限制)

### 5.2 MAVLink任务命令

| 命令 | ID | 飞艇处理 |
|------|----|---------|
| MAV_CMD_NAV_TAKEOFF | 22 | 垂直爬升到AS_TAKEOFF_ALT |
| MAV_CMD_NAV_LAND | 21 | 分阶段垂直下降 |
| MAV_CMD_NAV_WAYPOINT | 16 | 标准航点 |
| MAV_CMD_NAV_LOITER_UNLIM | 17 | 等效于Altitude模式 |
| MAV_CMD_NAV_RETURN_TO_LAUNCH | 20 | 等效于Altitude模式(返航高度) |

### 5.3 任务规划建议

**QGC任务编辑器建议**:
- 起飞航点: 仅高度参数,固定垂直爬升
- 航点间距离: 建议大于50m(考虑大惯量减速)
- 转向角度: 单次转向<30°,大角度拆分为多个小角度航点(S形)
- 降落航点: 设置降落区域半径(考虑漂移)
- 速度限制: 巡航速度<=MPC_XY_CRUISE

---

## 6. 虚拟摇杆UI定制

### 6.1 摇杆映射

**传统多旋翼映射(不适用于飞艇)**:
- Throttle → Thrust Z
- Pitch → Torque Y (俯仰)
- Roll → Torque X (横滚)
- Yaw → Torque Z (偏航)

**飞艇映射** (代码来源: AirshipTaskAltitude.cpp):
- Throttle → **高度调节** (通过altitude_target间接控制Thrust Z)
- Pitch杆 → **Thrust X (前进推力)**
- Roll杆 → **偏航角速率** (Torque Z间接,通过yawspeed设定值)
- Yaw杆 → **俯仰角** (Torque Y间接,通过pitch设定值)

**代码验证** (AirshipTaskAltitude.cpp L34-64):
```cpp
// pitch摇杆控制前进推力
_setpoint.thrust_x = forward_stick * MAX_THRUST_X;

// throttle控制高度目标
_altitude_target -= alt_rate * _stick_dt;
_setpoint.position(2) = _altitude_target;

// roll杆控制偏航速率
_setpoint.yawspeed = _roll_stick * _yaw_rate_max;

// yaw杆控制俯仰角
_setpoint.pitch = _yaw_stick * math::radians(15.f);
```

### 6.2 QGC虚拟摇杆定制建议

**左摇杆**:
- 上下(原Throttle) → 高度调节(升降)
- 左右(原Yaw) → 俯仰角

**右摇杆**:
- 上下(原Pitch) → 前进/后退(推进电机)
- 左右(原Roll) → 偏航角速率

**显示**:
- 左摇杆上下标"ALT"
- 左摇杆左右标"PITCH"
- 右摇杆上下标"THRUST"
- 右摇杆左右标"YAW"

---

## 7. 安全提示

### 7.1 起飞前检查清单

QGC建议提供起飞前检查清单:

**浮力检查**:
- [ ] 浮力平衡(净浮力≈0)
- [ ] 左右浮力差在容差内
- [ ] 鼓风机/阀门响应正常

**高度检查**:
- [ ] 当前高度 < AS_TAKEOFF_ALT
- [ ] AS_ALT_MAX 设置合理
- [ ] AS_ALT_MIN 设置合理

**传感器检查**:
- [ ] GPS锁定(HDOP<2)
- [ ] 罗盘校准
- [ ] 气压计正常
- [ ] 空速计正常
- [ ] IMU温度达标(45°C)

**通信检查**:
- [ ] RC信号良好
- [ ] 数传链路正常
- [ ] Companion Computer连接(可选)

**电池检查**:
- [ ] 电池电压充足
- [ ] 电池电流正常
- [ ] 剩余电量足够完成任务

### 7.2 飞行中监控

**实时监控项**:
- 高度(对照硬限位)
- 速度(对照速度限位)
- 俯仰角(<15°,气囊结构限制)
- 偏航角偏差
- 电池状态
- GPS状态
- 数据链状态
- 浮力调节系统状态

### 7.3 紧急情况处理

| 紧急情况 | QGC建议动作 |
|---------|------------|
| 推进电机故障 | 切换到Altitude模式,利用浮力保持高度 |
| 升力电机故障 | 切换到Manual模式,利用浮力缓慢下降 |
| 浮力系统故障 | 紧急排气,立即降落 |
| 配平故障 | 监控横滚角,手动补偿 |
| GPS丢失 | 切换到Stable模式(无位置控制) |
| 数据链丢失 | 自动返航(NAV_DLL_ACT=3) |
| RC丢失 | 自动返航(NAV_RCL_ACT=3) |
| 低电量 | 自动降落(COM_LOW_BAT_ACT=1) |

---

## 8. 地理围栏

### 8.1 围栏建议

- 最大高度: AS_ALT_MAX (150m,防超压)
- 最小高度: AS_ALT_MIN (2m,防撞地)
- 水平围栏: 根据飞行区域设置
- 返航高度: 20m (默认)

### 8.2 围栏违反动作

- 高度超限: 软限位先减速,硬限位强制返回
- 水平超限: 返航(NAV_RCL_ACT=3)

---

## 9. 常见问题

### Q1: QGC显示"未知飞行模式"?
**A**: 检查MAVLink消息中的custom_mode是否正确映射到飞艇模式。确保QGC版本支持 `PX4_CUSTOM_MAIN_MODE_*` 和 `PX4_CUSTOM_SUB_MODE_AUTO_TAKEOFF/LAND/MISSION`。参考 [04_modes.md](04_modes.md) 第3节。

### Q2: 参数修改后不生效?
**A**: 
1. 检查参数前缀是否正确(AS_或BALLOON_*)
2. 确认参数已通过PARAM_VALUE消息同步到QGC
3. 部分参数需要重启飞控才生效
4. 检查@group标签是否正确

### Q3: Offboard模式无法进入?
**A**:
1. 检查offboard_control_mode消息是否正确发布
2. 确认飞艇已解锁
3. 确认MAV_FWDEXTSP=1
4. 起飞模式前置条件: 高度<20m (参考 [04_modes.md](04_modes.md) 第3.6节)
5. 检查SET_ATTITUDE_TARGET消息格式(参考 [03_interfaces.md](03_interfaces.md) 第4节)

### Q4: 飞艇在QGC中显示为多旋翼?
**A**: 检查 `MAV_TYPE` 参数是否设置为7(MAV_TYPE_AIRSHIP),确认airframe配置正确(2058_lingyun01)。

### Q5: 浮力控制参数在QGC中看不到?
**A**: 
1. 确认ballast_control模块已启动(检查 `CONFIG_MODULES_BALLAST_CONTROL=y`)
2. 检查参数定义中的@group标签是否为"Ballast Control"
3. 确认 `BALLOON_AST_EN=1`

### Q6: 起飞被拒绝?
**A**: 起飞前置条件:
1. ARMED (已解锁)
2. `alt_agl < AS_TAKEOFF_ALT` (高度必须低于20m)
3. 收到Takeoff命令(MAVLink NAV_TAKEOFF)
检查PX4日志是否有"[TAKEOFF] Rejected"告警。

### Q7: 推进电机在起飞模式激活?
**A**: 这是异常情况。检查 `thrust_x < 0.01f` 检测逻辑是否正常。起飞模式应仅激活升力电机(0-3),推进电机(4-7)必须关闭。

### Q8: 实飞PID与仿真PID不一致?
**A**: 这是设计如此。实飞首飞PID在 `2058_lingyun01` 中减半,仿真PID在 `rc.lingyun01_defaults` 中调好。QGC可以提供两套预设,参考 [02_parameters.md](02_parameters.md) 第19节。

### Q9: 横滚控制如何工作?
**A**: 横滚由 ballast_control 模块独立级联PID控制(不通过电机):
1. **架构**: 角度外环(P+I) → 角速度内环(P+D) → 质量分配器 → 开关执行器
2. **执行器**: 四气囊空气囊(每囊4个执行器: 充气风机+抽气风机+充气阀+放气阀)
3. **物理原理**: 通过左右气囊空气质量差产生横滚力矩
4. **att_control**: torque_x 置0, 横滚不通过电机控制
5. **已验证**: 仿真9项检查全部通过, 稳态横滚角 < 1deg

参考 [02_parameters.md](02_parameters.md) 第8.1节横滚控制参数。

### Q10: 横滚控制参数在QGC中看不到?
**A**:
1. 确认ballast_control模块已启动(检查 `CONFIG_MODULES_BALLAST_CONTROL=y`)
2. 检查参数定义中的@group标签是否为"Ballast Roll Control"
3. 确认 `BALLOON_R_EN=1` (启用横滚主动控制)
4. 注意: 当BALLOON_R_EN=1时, TRIM_BALLOON_EN自动失效(代码互斥)

---

## 10. 参考资源

- PX4官方文档: https://docs.px4.io/
- QGC官方文档: https://docs.qgroundcontrol.com/
- MAVLink协议: https://mavlink.io/
- Gazebo Harmonic: https://gazebosim.org/
- CUAV x25-evo文档: https://doc.cuav.net/controller/x25/zh-hans/
- CUAV NEO3 Pro文档: https://doc.cuav.net/gps/neo-series-gnss/zh-hans/neo-3-pro.html
- CUAV SKYE2文档: https://doc.cuav.net/others/skye/zh-hans/skye2.html
- 灵云01号项目规则: `.trae/rules/airship*.md`
