# 02 - 完整参数表

**参数来源**:
- **代码默认值**: `src/modules/airship_att_control/airship_att_control_params.c` 和 `src/modules/ballast_control/ballast_control_params.c`
- **[仿真]值**: `ROMFS/px4fmu_common/init.d/rc.lingyun01_defaults` (仿真调好的值)
- **[实飞首飞]值**: `ROMFS/px4fmu_common/init.d/airframes/2058_lingyun01` (实飞首飞保守值,PID减半)

**QGC参数显示规则**:
- 实际生效值 = 代码默认值 ← rc.lingyun01_defaults覆盖 ← 2058_lingyun01再次覆盖
- QGC通过 MAVLink `PARAM_VALUE` 消息接收实际生效值
- QGC修改参数时发送 `PARAM_SET` 消息
- 所有 `AS_*` 和 `BALLOON_*/BLOWER_*/VALVE_*/TRIM_BALLOON_*` 参数都会出现在QGC参数列表

---

## 1. 高度PID参数 (AS_ALT_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_ALT_P | 0.3 | 0.3 | **0.15** | - | 高度比例增益 |
| AS_ALT_I | 0.02 | 0.02 | **0.01** | - | 高度积分增益 |
| AS_ALT_D | 3.0 | 3.0 | **1.5** | - | 高度微分增益(垂直速度阻尼) |
| AS_ALT_IMAX | 0.5 | 0.5 | **0.25** | - | 积分限幅 |
| AS_ALT_VMAX | 2.0 | 2.0 | **1.0** | m/s | 最大升降速度 |
| AS_ALT_VFF | 0.5 | 0.5 | **0.25** | - | 速度前馈增益 |
| AS_ALT_MAX | 150.0 | 150.0 | 150.0 | m AGL | 高度硬限位(防超压) |
| AS_ALT_MIN | 2.0 | 2.0 | 2.0 | m AGL | 高度硬限位(防撞地) |
| AS_ALT_SOFT | 140.0 | 140.0 | 140.0 | m AGL | 高度软限位预减速起始 |
| AS_ALT_SRATE | 2.0 | 2.0 | **1.0** | m/s | 摇杆高度调整速率 |

@group: Airship Attitude Control

---

## 2. 俯仰PID参数 (AS_PIT_*, AS_PR_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_PIT_P | 6.0 | 6.0 | **3.0** | - | 俯仰角比例增益(外环) |
| AS_PIT_I | 0.15 | 0.15 | **0.08** | - | 俯仰角积分增益 |
| AS_PIT_IMAX | 0.3 | 0.3 | **0.15** | - | 积分限幅 |
| AS_PR_P | 2.0 | 2.0 | **1.0** | - | 俯仰角速率比例(内环) |
| AS_PR_I | 0.5 | 0.5 | **0.25** | - | 俯仰角速率积分 |
| AS_PR_D | 0.5 | 0.5 | **0.25** | - | 俯仰角速率微分 |
| AS_PR_IMAX | 0.5 | 0.5 | **0.25** | - | 积分限幅 |
| AS_PIT_RMAX | 0.349 | 0.349 | 0.349 | rad/s | 最大俯仰角速度(20°/s) |
| AS_PIT_FF | 1.0 | 1.0 | **0.5** | - | 推进俯仰耦合前馈 |

@group: Airship Attitude Control

**调参说明**:
- 仿真值已针对大惯量(Iyy=112200)调好,对抗Munk力矩
- 实飞首飞P和D增益减半,首飞后根据响应逐步调整
- AS_PIT_FF 通过增益调度: `pitch_p_effective = AS_PIT_P + AS_PIT_FF * thrust_x_filtered`

---

## 3. 偏航PID参数 (AS_YAW_*, AS_YR_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_YAW_P | 1.0 | 1.0 | **0.5** | - | 偏航角比例增益(外环) |
| AS_YAW_I | 0.05 | 0.05 | **0.03** | - | 偏航角积分增益 |
| AS_YAW_IMAX | 0.2 | 0.2 | **0.1** | - | 积分限幅 |
| AS_YR_P | 0.5 | **2.0** | **0.25** | - | 偏航角速率比例(内环) |
| AS_YR_I | 0.5 | 0.5 | **0.25** | - | 偏航角速率积分 |
| AS_YR_D | 0.0 | 0.0 | 0.0 | - | 偏航角速率微分 |
| AS_YR_IMAX | 0.2 | 0.2 | **0.1** | - | 积分限幅 |
| AS_YAW_RMAX | 0.524 | 0.524 | 0.524 | rad/s | 最大偏航角速度(30°/s) |
| AS_YAW_TMAX | 0.3 | **0.5** | **0.2** | - | 最大偏航扭矩 |

@group: Airship Attitude Control

**调参说明**:
- 仿真值AS_YR_P从0.5升到2.0,让torque_z快速饱和到AS_YAW_TMAX=0.5
- 实飞首飞保守值AS_YR_P=0.25, AS_YAW_TMAX=0.2
- 偏航受气动力矩物理限制,推进电机差动主要产生侧向位移,大角度转向需S形

---

## 4. 位置/速度PID参数 (AS_VEL_*, AS_POS_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_VEL_XY_P | 0.5 | 0.5 | **0.25** | - | 水平速度P增益 |
| AS_VEL_XY_I | 0.02 | 0.02 | **0.01** | - | 水平速度I增益 |
| AS_VEL_XY_D | 0.1 | 0.1 | **0.05** | - | 水平速度D增益 |
| AS_VEL_XY_IMAX | 1.0 | 1.0 | **0.5** | - | 速度积分限幅 |
| AS_VEL_XY_MAX | 15.0 | 15.0 | **10.0** | m/s | 最大水平速度 |
| AS_POS_XY_P | 0.3 | 0.3 | **0.15** | - | 位置P增益 |
| AS_POS_XY_MAX | 30.0 | 30.0 | **15.0** | m | 最大位置误差 |

@group: Airship Attitude Control

---

## 5. 起飞参数 (AS_TAKEOFF_*, AS_TKF_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_TAKEOFF_ALT | 20.0 | 20.0 | 20.0 | m AGL | 起飞目标高度 |
| AS_TKF_HOLD_T | 20.0 | 20.0 | 20.0 | s | Hold阶段保持时间 |
| AS_TKF_ALT_TOL | 2.0 | 2.0 | 2.0 | m | Hold阶段高度容差 |
| AS_TAKEOFF_RAMP | 5.0 | 5.0 | 5.0 | s | 软启动渐增时间 |

@group: Airship Attitude Control

**起飞逻辑**:
1. 前置条件: ARMED + 高度 < AS_TAKEOFF_ALT
2. Climb阶段: 升力电机垂直爬升,推进电机关闭,AS_TAKEOFF_RAMP软启动
3. Hold阶段: 到达目标高度后保持AS_TKF_HOLD_T秒,容差AS_TKF_ALT_TOL
4. 自动切换: Hold完成后切换到Altitude模式悬停

---

## 6. 降落参数 (AS_LND_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_LND_DONE_ALT | 3.0 | 3.0 | 3.0 | m AGL | 降落完成高度 |
| AS_LND_VHI | 1.5 | 1.5 | 1.5 | m/s | 高空(alt>10m)下降速度 |
| AS_LND_VMID | 1.0 | 1.0 | 1.0 | m/s | 中空(5m<alt<=10m)下降速度 |
| AS_LND_VLO | 0.5 | 0.5 | 0.5 | m/s | 低空(2m<alt<=5m)下降速度 |
| AS_LND_VGND | 0.2 | 0.2 | 0.2 | m/s | 接地(alt<=2m)下降速度 |

@group: Airship Attitude Control

**降落逻辑**:
- 分阶段下降速度,接地时AS_LND_VGND=0.2m/s gentle touchdown
- Done状态判断: 仅使用 `alt_agl <= AS_LND_DONE_ALT`,不依赖landed条件
- 降落到Done高度后自动disarm

---

## 7. 自动测试/调参参数 (AS_TST_*, AS_AT_*)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_TST_EN | 0 | 0 | 0 | - | 自动阶跃测试使能(0=禁用,1=启用) |
| AS_TST_PIT | 10.0 | 10.0 | 10.0 | deg | 阶跃测试俯仰角 |
| AS_TST_YAW | 15.0 | 15.0 | 15.0 | deg | 阶跃测试偏航角 |
| AS_AT_EN | 0 | 0 | 0 | - | PID自整定使能(0=禁用,1=俯仰,2=偏航,3=高度) |
| AS_AT_AMP | 0.1 | 0.1 | 0.1 | - | 继电器反馈振幅 |
| AS_AT_DUR | 30.0 | 30.0 | 30.0 | s | 自整定持续时间 |

@group: Airship Attitude Control

**测试流程**:
- AS_TST_EN=1时: hold 5s → pitch +10deg 10s → hold 5s → yaw +15deg 10s → hold 5s
- AS_AT_EN=1/2/3时: 应用继电器(bang-bang)输入,测量振荡,用Ziegler-Nichols计算PID增益,结果打印到console

---

## 8. 浮力控制参数 (BALLOON_*, BLOWER_*, VALVE_*, TRIM_BALLOON_*)

@group: Ballast Control

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| BALLOON_AST_EN | 1 | **0** | 1 | - | 启用浮力辅助控制(仿真禁用,改用横滚主动控制) |
| BALLOON_DEADZONE | 0.5 | 0.5 | 0.5 | m | 高度死区 |
| BALLOON_THRSHLD | 2.0 | 2.0 | 2.0 | m | 鼓风机/阀门切换阈值 |
| BALLOON_P_GAIN | 0.8 | 0.8 | 0.8 | - | 高度PID P |
| BALLOON_I_GAIN | 0.05 | 0.05 | 0.05 | - | 高度PID I |
| BALLOON_D_GAIN | 0.2 | 0.2 | 0.2 | - | 高度PID D |
| BALLOON_I_MAX | 50.0 | 50.0 | 50.0 | - | 积分限幅 |
| BLOWER_TAU | 10.0 | 10.0 | 10.0 | s | 鼓风机时间常数 |
| VALVE_OPEN_DELAY | 0.5 | 0.5 | 0.5 | s | 阀门开启延迟 |
| TRIM_BALLOON_EN | 1 | 1 | 1 | - | 启用左右浮力配平 |
| TRIM_BALLOON_P | 0.1 | 0.1 | 0.1 | - | 配平P |
| TRIM_BALLOON_I | 0.01 | 0.01 | 0.01 | - | 配平I |
| TRIM_BALLOON_IMX | 10.0 | 10.0 | 10.0 | - | 配平积分限幅 |
| BALLOON_RATE_MAX | 20.0 | 20.0 | 20.0 | N/s | 浮力调节最大速率 |

### 8.1 横滚控制参数 (BALLOON_R_*, BALLOON_RR_*, BLWR_*, VALVE_*)

@group: Ballast Roll Control

ballast_control 独立级联PID（角度外环P+I → 角速度内环P+D → 质量分配器 → 开关执行器），不依赖 att_control。

**架构说明**:
- 外环: 角度误差 → PID(P+I) → 目标角速度
- 内环: 角速度误差 → PID(P+D) → 横滚力矩需求 [-1,1]
- 质量分配器: 力矩需求 → 各气囊目标质量(外囊70%+内囊30%)
- 开关执行器: 滞环控制风机/阀门开关

**物理基础** (AirshipDynamics力矩公式):
```
momentX = g * (mLI*armInner + mLO*armOuter - mRI*armInner - mRO*armOuter)
```
- LI/LO: Y正方向(物理右侧), 质量增加产生正roll(右侧下沉)
- RI/RO: Y负方向(物理左侧), 质量增加产生负roll(左侧下沉)

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| BALLOON_R_EN | 1 | 1 | 1 | - | 启用横滚主动控制(四气囊浮力差) |
| BALLOON_R_P | 1.0 | **2.0** | 1.0 | - | 横滚角度外环P增益 |
| BALLOON_R_I | 0.05 | **0.1** | 0.05 | - | 横滚角度外环I增益 |
| BALLOON_R_IMX | 0.3 | 0.3 | 0.3 | - | 横滚角度外环积分限幅 |
| BALLOON_RR_P | 0.5 | **1.0** | 0.5 | - | 横滚角速度内环P增益 |
| BALLOON_RR_D | 0.1 | 0.1 | 0.1 | - | 横滚角速度内环D增益 |
| BALLOON_R_MAX | 0.5 | 0.5 | 0.5 | - | 横滚力矩需求限幅 |
| BALLOON_M_MAX | 128.5 | 128.5 | 128.5 | kg | 单个空气囊最大空气质量(5kPa表压) |
| BLWR_FLOW | 0.102 | **0.5** | 0.102 | kg/s | 风机空气质量流量(仿真加速) |
| VALVE_HYST | 2.0 | **0.5** | 2.0 | kg | 阀门开关滞环(仿真加速) |
| VALVE_MIN_T | 0.5 | 0.5 | 0.5 | s | 阀门/风机最小开启时间 |

**调参说明**:
- 仿真值已验证: 9项检查全部通过, 稳态横滚角 < 1deg
- BLWR_FLOW和VALVE_HYST在仿真中放大以加速响应(实际风机流量0.102 kg/s)
- 实飞首飞值使用代码默认值, 待实飞验证后调整
- 当 BALLOON_R_EN=1 时, TRIM_BALLOON_EN 自动失效(代码互斥)

---

## 9. 控制分配物理常数 (CA_AS_*)

@group: Control Allocation

| 参数名 | 值 | 单位 | 说明 |
|--------|------|------|------|
| CA_AS_K_LUP | 196.0 | N | 上升电机推力系数(M0/M3, 20kg级) |
| CA_AS_K_LDN | 392.0 | N | 下降电机推力系数(M1/M2, 40kg级) |
| CA_AS_K_PROP | 726.3 | N | 推进电机推力系数(M4-M7) |
| CA_AS_PZ_PROP | 1.503 | m | 推进电机到重心垂直距离 |
| CA_AS_PX_FRONT | 10.232 | m | 前部升力电机到重心水平距离 |
| CA_AS_PX_REAR | 14.518 | m | 后部升力电机到重心水平距离 |

---

## 10. 控制分配配置参数 (CA_*)

@group: Control Allocation

| 参数名 | 值 | 说明 |
|--------|------|------|
| CA_AIRFRAME | 9 | Custom (支持X轴+Z轴混合推力) |
| CA_ROTOR_COUNT | 8 | 8个电机(4升力+4推进) |
| CA_METHOD | 0 | 控制分配方法 |
| CA_SV_CS_COUNT | 0 | **新方案无舵机**: control_allocator不发布actuator_servos |
| CA_R_REV | 255 | 所有电机可逆映射(bit0-7=1) |

**升力电机方向配置**:
- M0/M3: `CA_ROTOR*_AZ=-1` (推力向上)
- M1/M2: `CA_ROTOR*_AZ=+1` (推力向下)

---

## 11. 位置/速度限制参数 (MPC_*)

@group: Multicopter Position Control (飞艇复用)

| 参数名 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|--------------|------|------|
| MPC_Z_VEL_MAX_UP | 2.0 | **1.0** | m/s | 最大上升速度 |
| MPC_Z_VEL_MAX_DN | 1.5 | **0.8** | m/s | 最大下降速度 |
| MPC_XY_VEL_MAX | 20.0 | **10.0** | m/s | 最大水平速度 |
| MPC_XY_CRUISE | 12.0 | **6.0** | m/s | 巡航速度 |
| MPC_ACC_HOR_MAX | 1.5 | **0.8** | m/s² | 最大水平加速度 |
| MPC_ACC_DOWN_MAX | 0.5 | **0.3** | m/s² | 最大下降加速度 |
| MPC_THR_MIN | 0.0 | 0.0 | - | 最小推力(中性浮力=0) |
| MPC_THR_MAX | 1.0 | 1.0 | - | 最大推力 |
| MPC_THR_HOVER | 0.0 | 0.0 | - | 悬停推力(中性浮力=0) |
| MPC_MAN_TILT_MAX | 15.0 | 15.0 | deg | 最大俯仰角(气囊结构限制) |
| MPC_MAN_Y_MAX | 30.0 | 30.0 | deg/s | 最大偏航速率 |

---

## 12. 着陆检测参数 (LNDAS_*)

@group: Land Detector

| 参数名 | 值 | 单位 | 说明 |
|--------|------|------|------|
| LNDAS_XY_VEL_MAX | 0.5 | m/s | 水平速度阈值 |
| LNDAS_Z_VEL_MAX | 0.3 | m/s | 垂直速度阈值 |
| LNDAS_ROT_MAX | 3.0 | deg/s | 旋转速度阈值 |
| LNDAS_GND_PROX | 1.0 | m | 地面接近距离 |
| LNDAS_GND_ALT | 1.0 | m | 地面高度 |
| LNDAS_TOUCH_DIST | 0.3 | m | 接触距离 |

**注意**: 飞艇悬停时 `landed=true` 是正确行为,EKF2 ZUPT/ZGUPT保持激活。

---

## 13. 安全参数 (实飞)

| 参数名 | [仿真]值 | [实飞首飞]值 | 说明 |
|--------|---------|--------------|------|
| COM_ARM_WO_GPS | 1 | **0** | 仿真允许无GPS解锁,实飞必须GPS锁定 |
| COM_LOW_BAT_ACT | 0 | **1** | 仿真禁用,实飞启用低电量自动降落 |
| NAV_RCL_ACT | 0 | **3** | 仿真禁用,实飞RC丢失返航 |
| NAV_DLL_ACT | 0 | **3** | 仿真禁用,实飞数据链丢失返航 |
| COM_DL_LOSS_T | (默认) | **30.0** | 实飞数据链丢失超时(150km链路) |
| COM_RC_LOSS_T | (默认) | **5.0** | 实飞RC丢失超时 |
| COM_FAIL_ACT_T | 30 | 30 | failsafe动作超时 |
| COM_DISARM_LAND | (默认) | **0** | 着陆后不自动disarm(中性浮力) |
| COM_DISARM_PRFLT | (默认) | **0** | ARM后未起飞不disarm |
| COM_RCL_EXCEPT | (默认) | **4** | RC丢失后保持Position模式 |
| FD_FAIL_P | 0 | 0 | 禁用俯仰故障检测 |
| FD_FAIL_R | 0 | 0 | 禁用横滚故障检测 |
| FD_ESCS_EN | 0 | 0 | 禁用ESC故障检测 |
| CBRK_SUPPLY_CHK | 894281 | (默认) | 仿真禁用电源检查,实飞恢复 |
| COM_ARM_IMU_ACC | 2.0 | **0.7** | 加速度计偏差检查(仿真放宽,实飞恢复) |

---

## 14. EKF2参数 (实飞)

| 参数名 | [实飞首飞]值 | 说明 |
|--------|--------------|------|
| EKF2_ACC_NOISE | 0.5 | 加速度计噪声(飞艇振动大) |
| EKF2_ACC_B_NOISE | 0.01 | 加速度计偏差噪声 |
| EKF2_ABL_LIM | 0.4 | 加速度计偏差学习范围 |
| EKF2_MAG_CHECK | 0 | 禁用磁力计一致性检查 |
| EKF2_MAG_GATE | 5.0 | 放宽磁力计创新门限 |
| EKF2_MAG_NOISE | 0.03 | 磁力计噪声 |
| EKF2_GYR_NOISE | 0.01 | 陀螺仪噪声 |
| EKF2_MAG_DECL | 0.0 | 磁偏角(0=自动获取) |
| EKF2_DECL_TYPE | 1 | 启用geo_lookup磁偏角 |
| EKF2_GPS_V_NOISE | 0.5 | GPS速度观测噪声(默认值) |
| EKF2_GPS_P_NOISE | 0.5 | GPS位置观测噪声(默认值) |

---

## 15. MAVLink配置参数

| 参数名 | 值 | 说明 |
|--------|------|------|
| MAV_TYPE | 7 | MAV_TYPE_AIRSHIP |
| MAV_FWDEXTSP | 1 | 启用外部控制指令转发(Offboard需要) |
| MAV_1_CONFIG | 101 | TELEM1端口 |
| MAV_1_BAUD | 57600 | 数传波特率 |
| MAV_1_MODE | 1 | Normal模式 |
| MAV_1_RADIO_CTL | 0 | 禁用MAVLink无线电控制 |
| MAV_2_CONFIG | 1000 | Ethernet端口(Companion Computer) |
| MAV_2_BROADCAST | 1 | 广播模式 |
| MAV_2_MODE | 0 | Custom模式 |
| MAV_2_RATE | 100000 | 100kB/s(以太网高带宽) |
| MAV_2_REMOTE_PRT | 14550 | 远程端口 |
| MAV_2_UDP_PRT | 14550 | 本地UDP端口 |

---

## 16. GPS与传感器参数

| 参数名 | 值 | 说明 |
|--------|------|------|
| GPS_1_PROTOCOL | 2 | DroneCAN (CUAV NEO3 Pro via CAN1) |
| SENS_GPS_MASK | 3 | 双GPS自动切换 |
| UAVCAN_ENABLE | 1 | 仅传感器(GPS/磁力计/电池) |
| UAVCAN_SUB_GPS | 1 | 订阅UAVCAN GPS |
| UAVCAN_SUB_BAT | 1 | 订阅UAVCAN电池 |
| SYS_HAS_MAG | 1 | 启用罗盘 |
| SENS_BARO_QNH | 1013.25 | 气压计QNH |
| SENS_EN_ASPD | 1 | 启用空速计驱动 |
| ASPD_PRIMARY | 1 | 使用空速计作为主空速源 |
| SENS_ARSPD_CFG | 4 | I2C4 (EXT2端口, SKYE2) |
| ASPD_TYPE | 2 | MS4525 (SKYE2兼容) |

---

## 17. 输出配置参数 (PWM_*)

### MAIN端口 (8电机, PWM_MAIN_FUNC1-8)

| 参数 | 值 | 说明 |
|------|------|------|
| PWM_MAIN_FUNC1-4 | 101-104 | 升力电机M0-M3 (Motor 1-4) |
| PWM_MAIN_FUNC5-8 | 105-108 | 推进电机M4-M7 (Motor 5-8) |
| PWM_MAIN_DIS1-8 | 1500 | 停转PWM(标准PWM) |
| PWM_MAIN_MIN1-8 | 1000 | 最低速PWM |
| PWM_MAIN_MAX1-8 | 2000 | 最高速PWM |

### AUX端口 (鼓风机+阀门, PWM_AUX_FUNC1-4)

| 参数 | 值 | 说明 |
|------|------|------|
| PWM_AUX_FUNC1 | 201 | Servo1 = 左鼓风机 |
| PWM_AUX_FUNC2 | 202 | Servo2 = 右鼓风机 |
| PWM_AUX_FUNC3 | 203 | Servo3 = 左阀门 |
| PWM_AUX_FUNC4 | 204 | Servo4 = 右阀门 |
| PWM_AUX_DIS1-4 | 1500 | 停转PWM |
| PWM_AUX_MIN1-4 | 1000 | 最小PWM |
| PWM_AUX_MAX1-4 | 2000 | 最大PWM |

**注**: 鼓风机/阀门通过 `ballast_output` 模块输出到 `actuator_servos`,FunctionServos订阅`actuator_servos`映射到PWM。

---

## 18. 系统配置参数

| 参数名 | 值 | 说明 |
|--------|------|------|
| MIXER_FILE | /etc/mixers/lingyun01.mix | 混频器文件(注:实际改用控制分配器,mixer文件可能不存在) |
| MIXER_AIRMODE | 0 | 禁用airmode |
| MOT_NOUT | 12 | 输出通道总数(8电机+2鼓风机+2阀门) |
| SDLOG_MODE | 2 | 日志模式 |
| NAV_ACC_RAD | 3.0 | 导航精度半径 |

---

## 19. 参数前缀规范

| 前缀 | 模块 | @group | 说明 |
|------|------|--------|------|
| AS_ | airship_att_control | Airship Attitude Control | 飞艇姿态控制参数 |
| BALLOON_* | ballast_control | Ballast Control | 浮力调节参数 |
| BLOWER_* | ballast_control | Ballast Control | 鼓风机控制参数 |
| VALVE_* | ballast_control | Ballast Control | 阀门控制参数 |
| TRIM_BALLOON_* | ballast_control | Ballast Control | 浮力配平参数 |
| CA_AS_* | control_allocator | Control Allocation | 飞艇控制分配物理常数 |
| CA_ROTOR* | control_allocator | Control Allocation | 电机位置/方向配置 |
| LNDAS_* | land_detector | Land Detector | 飞艇着陆检测阈值 |
| MPC_* | navigator | Multicopter Position Control | 位置/速度限制(飞艇复用) |

## 20. 参数分组(QGC参数页面建议)

QGC通过 `@group` 标签自动分组,建议QGC参数界面按以下分组显示:

1. **Airship Attitude Control** (AS_* 参数)
   - 高度PID子组
   - 俯仰PID子组
   - 偏航PID子组
   - 起飞/降落参数子组
   - 位置/速度PID子组
   - 自动测试/调参子组

2. **Ballast Control** (BALLOON_*/BLOWER_*/VALVE_*/TRIM_BALLOON_* 参数)
   - 浮力辅助控制开关
   - 高度死区和阈值
   - PID参数
   - 配平参数

3. **Control Allocation** (CA_* 参数)
   - 物理常数
   - 电机配置(只读,调试用)

4. **Land Detector** (LNDAS_* 参数)

5. **Multicopter Position Control** (MPC_* 参数,飞艇复用)
