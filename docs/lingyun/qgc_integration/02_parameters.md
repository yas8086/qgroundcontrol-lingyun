# 02 - 完整参数表

**文档版本**: 3.0 (基于2026-08-30全量代码分析, V2架构)
**最后更新**: 2026-08-30

**参数来源与覆盖顺序** (实际生效值 = 低优先级被高优先级覆盖):
1. **代码默认值**: `src/modules/airship_att_control/airship_att_control_params.c`、`src/modules/ballast_control/ballast_control_params.c`、`src/modules/control_allocator/control_allocator_params_airship.c`
2. **[仿真]值**: `ROMFS/px4fmu_common/init.d/rc.lingyun01_defaults` (set-default)
3. **[实飞首飞]值**: `ROMFS/px4fmu_common/init.d/airframes/2058_lingyun01` (set-default或param set, 优先级最高)

**QGC参数显示规则**:
- QGC通过 MAVLink `PARAM_VALUE` 接收实际生效值, `PARAM_SET` 修改
- 所有 `AS_*`、`BALLOON_*`、`CA_AS_*`、`LNDAS_*` 参数都会出现在QGC参数列表
- 参数分组通过 `@group` 标签: "Airship Attitude Control" / "Ballast Control" / "Control Allocation"

---

## 1. 高度PID参数 (AS_ALT_*) @group: Airship Attitude Control

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_ALT_P | 0.3 | 0.3 | 0.15 | - | 高度→目标速度 P增益 |
| AS_ALT_I | 0.02 | 0.02 | 0.01 | - | 速度环积分增益 |
| AS_ALT_D | 3.0 | 3.0 | 1.5 | - | 速度环P增益(命名历史遗留, 实为速度P) |
| AS_ALT_IMAX | 0.5 | 0.5 | 0.25 | - | 积分限幅 |
| AS_ALT_VMAX | 2.0 | 2.0 | 1.0 | m/s | 最大升降速度 |
| AS_ALT_VFF | 0.5 | 0.5 | 0.25 | - | 速度前馈(中性浮力稳态速度需持续推力) |
| AS_ALT_MAX | 150.0 | 150.0 | 150.0 | m AGL | 高度硬上限(防气囊超压, 0=禁用) |
| AS_ALT_MIN | 2.0 | 2.0 | 2.0 | m AGL | 高度硬下限(V6修复: 触发时目标=当前高度悬浮, 非强制抬升) |
| AS_ALT_SOFT | 140.0 | 140.0 | 140.0 | m AGL | 软限位: 速度线性预减速+推力截断(仅限上升方向) |
| AS_ALT_SRATE | 2.0 | 2.0 | 1.0 | m/s | 摇杆高度调整速率 |

## 2. 俯仰PID参数 @group: Airship Attitude Control

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_PIT_P | 6.0 | 6.0 | 3.0 | - | 俯仰角外环P(输出±4 rad/s) |
| AS_PIT_I | 0.15 | 0.15 | 0.08 | - | 俯仰角外环I |
| AS_PIT_IMAX | 0.3 | 0.3 | 0.15 | - | 外环积分限幅 |
| AS_PR_P | 2.0 | 2.0 | 1.0 | - | 俯仰角速率内环P(输出±3) |
| AS_PR_I | 0.5 | 0.5 | 0.25 | - | 内环I |
| AS_PR_D | 0.5 | 0.5 | 0.25 | - | 内环D(纯阻尼) |
| AS_PR_IMAX | 0.5 | 0.5 | 0.25 | - | 内环积分限幅 |
| AS_PIT_RMAX | 0.349 | 0.349 | 0.349 | rad/s | 摇杆最大俯仰角速度(20°/s) |
| AS_PIT_FF | 1.0 | 1.0 | 0.5 | - | 推进俯仰耦合前馈: pitch_p_eff = PIT_P + FF*thrust_x滤波 |

**附加补偿(代码内实现, 无参数)**:
- Munk力矩前馈: `munk_y = 600*vx_body*vz_body`, `ff = -0.8*munk/3975`, 限幅±6
- 俯仰-速度保护: 俯仰误差>10°时线性限制前进推力(30°时归零)

## 3. 偏航PID参数 @group: Airship Attitude Control

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_YAW_P | 1.0 | 1.0 | 0.5 | - | 偏航角外环P(输出±2 rad/s) |
| AS_YAW_I | 0.05 | 0.05 | 0.03 | - | 外环I |
| AS_YAW_IMAX | 0.2 | 0.2 | 0.1 | - | 外环积分限幅 |
| AS_YR_P | 1.0 | **2.0** | 0.25 | - | 偏航角速率内环P(输出±yaw_torque_max) |
| AS_YR_I | 0.5 | 0.5 | 0.25 | - | 内环I |
| AS_YR_D | 0.0 | 0.0 | 0.0 | - | 内环D |
| AS_YR_IMAX | 0.2 | 0.2 | 0.1 | - | 内环积分限幅 |
| AS_YAW_RMAX | 0.524 | 0.524 | 0.524 | rad/s | 摇杆最大偏航角速度(30°/s) |
| AS_YAW_TMAX | 0.8 | **0.8** | 0.2 | - | 最大偏航力矩(V5回退: 0.8配合PROP_MAX=0.6为性能拐点) |

## 4. 横滚PID参数 (V2新增, Roll闭环) @group: Airship Attitude Control

| 参数名 | 代码默认 | 单位 | 说明 |
|--------|---------|------|------|
| AS_ROLL_P | 1.0 | - | 横滚角外环P(输出±2 rad/s) |
| AS_ROLL_I | 0.05 | - | 外环I |
| AS_ROLL_IMAX | 0.3 | - | 外环积分限幅 |
| AS_RR_P | 0.5 | - | 横滚角速率内环P(输出±1) |
| AS_RR_I | 0.1 | - | 内环I |
| AS_RR_D | 0.1 | - | 内环D |
| AS_RR_IMAX | 0.2 | - | 内环积分限幅 |
| AS_ROLL_RMAX | 0.349 | rad/s | 摇杆最大横滚角速度 |

**注意**: 横滚目标恒为0(回水平), 由上升电机(0-3)左右差动实现, 力臂PY≈6.34m。

## 5. 位置/速度PID参数 (Position模式) @group: Airship Attitude Control

| 参数名 | 代码默认 | [仿真]值 | [实飞首飞]值 | 单位 | 说明 |
|--------|---------|---------|--------------|------|------|
| AS_POS_XY_P | 0.05 | 0.05 | 0.05 | - | 位置P增益(误差→速度) |
| AS_VEL_XY_P | 0.8 | 0.8 | 0.25 | - | L1视线导引速度P |
| AS_VEL_XY_I | 0.02 | 0.02 | 0.01 | - | 速度I |
| AS_VEL_XY_D | 2.0 | 2.0 | 0.05 | - | 速度D(阻尼) |
| AS_VEL_XY_IMAX | 1.0 | 1.0 | 0.5 | - | 积分限幅 |
| AS_VEL_XY_MAX | 2.0 | 2.0 | 2.0 | m/s | 最大水平速度(超LOS分量→停推保护) |
| AS_POS_XY_MAX | 30.0 | 30.0 | 15.0 | m | 位置误差限幅 |

**Position模式算法要点**: 误差>0.5m时yaw_setpoint=atan2指向目标; L1导引 `l1_weight=max(cos(yaw_err),0)` 边转边逼近; 停推保护仅判沿目标方向速度分量(风漂移不触发)。

## 6. 起飞参数 @group: Airship Attitude Control

| 参数名 | 代码默认 | 单位 | 说明 |
|--------|---------|------|------|
| AS_TAKEOFF_ALT | 20.0 | m AGL | 起飞目标高度(绝对AGL, V3修复非相对量) |
| AS_TKF_HOLD_T | 20.0 | s | Hold阶段保持时间 |
| AS_TKF_ALT_TOL | 2.0 | m | Hold高度容差(超差重置计时) |
| AS_TAKEOFF_RAMP | 5.0 | s | Climb软启动时间(推力线性爬升) |
| AS_TKF_VMAX | 0.5 | m/s | Climb爬升限速(V2新增, 防大惯量超调) |

**起飞状态机**: Settle(0-5s保持当前高度) → Climb(软启动+限速爬升) → Hold(±2m内连续20s) → Complete(自动发DO_SET_MODE切LOITER)。
前置条件: ARMED + `alt_agl < AS_TAKEOFF_ALT`(否则PX4_WARN拒绝, 保持Altitude悬停)。

## 7. 降落参数 @group: Airship Attitude Control

| 参数名 | 代码默认 | 单位 | 说明 |
|--------|---------|------|------|
| AS_LND_DONE_ALT | 3.0 | m AGL | 降落完成高度(到达后自动强制DISARM) |
| AS_LND_VHI | 1.5 | m/s | >10m下降速度 |
| AS_LND_VMID | 1.0 | m/s | 5-10m下降速度 |
| AS_LND_VLO | 0.5 | m/s | 2-5m下降速度 |
| AS_LND_VGND | 0.2 | m/s | <2m下降速度 |

**降落实现**: 不用位置PID控高, 直接速度控制(`updateAltitudeVelocity`), 水平位置PID保持防漂移。Done判据仅用 `alt_agl <= AS_LND_DONE_ALT`, 不依赖landed标志。

## 8. 自动测试/调参参数 @group: Airship Attitude Control

| 参数名 | 代码默认 | 说明 |
|--------|---------|------|
| AS_TST_EN | 0 | 自动阶跃测试(解锁后: hold 5s→pitch+AS_TST_PIT 10s→hold→yaw+AS_TST_YAW 10s→hold) |
| AS_TST_PIT | 10.0 deg | 俯仰阶跃幅值 |
| AS_TST_YAW | 15.0 deg | 偏航阶跃幅值 |
| AS_AT_EN | 0 | 继电反馈PID自整定(1=Pitch/2=Yaw/3=Altitude) |
| AS_AT_AMP | 0.1 | 继电器幅值 |
| AS_AT_DUR | 30.0 s | 整定时长(需≥2个振荡周期) |

**注意**: 自整定结果只打印到console(`[AT] COMPLETE: Tu/Ku/Kp/Ki/Kd`), 需手动写参数。

## 9. 浮力控制参数 (ballast_control) @group: Ballast Control

| 参数名 | 代码默认 | 单位 | 说明 |
|--------|---------|------|------|
| BALLOON_AST_EN | 1 | - | 启用浮力辅助控制 |
| BALLOON_DEADZONE | 0.5 | m | 高度死区(\|err\|<0.5m不动作) |
| BALLOON_THRSHLD | 2.0 | m | **死参数**(V2遗留: 定义+加载但Run()中零引用) |
| BALLOON_P_GAIN | 0.8 | - | 高度PID P |
| BALLOON_I_GAIN | 0.05 | - | 高度PID I |
| BALLOON_D_GAIN | 0.2 | - | 高度PID D(误差低通alpha=0.1) |
| BALLOON_I_MAX | 50.0 | - | 积分限幅 |
| BALLOON_RATE_MAX | 20.0 | N/s | 净浮力指令变化率限制 |
| BALLOON_M_MAX | 128.5 | kg | 单囊最大空气质量(净浮力限幅±500N硬编码) |
| BLWR_FLOW | 0.102 | kg/s | 单囊风机充气流量(仿真机型覆盖为0.5加速) |
| BALLOON_MIN_ON | 5.0 | s | 充/排气最小持续时长(modeGuard互锁防频繁启停) |
| BALLOON_SWT_GD | 2.0 | s | 充/排切换死区(停止后需等2s, 防管道串压) |
| BALLOON_EMG_EN | 1 | - | 启用failsafe紧急排气 |
| VALVE_OPEN_DELAY | 0.5 | s | 阀门机械延迟模拟 |
| VALVE_FLOW_MAX | 0.102 | kg/s | 阀门排气流量(孔口压差流动) |
| BLOWER_TAU | 10.0 | s | 风机一阶惯性时间常数 |

**已删除参数**: `TRIM_BALLOON_*` 全族(V2四囊同步架构, 气囊不参与横滚, 横滚由上升电机左右差动闭环)。QGC参数页不应再展示TRIM_BALLOON组。

**安全逻辑**:
- 近地保护: 目标AGL<1m时禁止充气(target_low_guard)
- 紧急排气: `vehicle_status.failsafe` 或 自主检测(RC/GCS任一丢失超5s) → 强制排气
- 超压告警: 压力>4.75kPa(95%) PX4_WARN, <4.0kPa滞回解除
- 未解锁: 全零输出(风机停+阀断电常闭)

## 10. 浮力输出参数 (ballast_output) @group: Ballast Control

| 参数名 | 代码默认 | 说明 |
|--------|---------|------|
| BALLOON_OUT_EN | 1 | 输出使能(还需ARMED+setpoint 1s内新鲜, 三重门控) |

## 11. 控制分配参数 (CA_AS_* / CA_*) @group: Control Allocation

| 参数名 | 值 | 说明 |
|--------|------|------|
| CA_AIRFRAME | 9 | Custom |
| CA_ROTOR_COUNT | 10 | 10电机(4上升+2下降+4推进) |
| CA_METHOD | 0 | 分配方法 |
| CA_SV_CS_COUNT | 0 | 无控制面; actuator_servos由ballast_output独占发布 |
| CA_R_REV | 1023 (0x3FF) | 全部10电机可逆映射 |
| CA_AS_K_LUP/LDN | 222.5/222.5 | 上升/下降推力系数(下降系数声明未用) |
| CA_AS_K_PROP | 1352.4 | 推进推力系数 |
| CA_AS_PZ_PROP | 0.878 m | 推进电机-重心垂直距 |
| CA_AS_PX_FRONT/REAR | 7.557/9.843 m | 上升组前/后力臂 |
| CA_AS_PROP_MAX | 0.6 | 推进最大油门 |
| CA_AS_PT_EN/SIDE/THR | 0/0/0.3 | PropTest(ACRO模式单侧推进测试) |
| CA_ROTOR0-9 PX/PY/PZ/AX/AY/AZ/CT/KM | 见05_hardware | FRD坐标, 与SDF一一对应 |

## 12. 位置/速度限制 (MPC_*, navigator复用)

| 参数名 | [仿真]值 | [实飞首飞]值 | 单位 |
|--------|---------|--------------|------|
| MPC_Z_VEL_MAX_UP | 2.0 | 1.0 | m/s |
| MPC_Z_VEL_MAX_DN | 1.5 | 0.8 | m/s |
| MPC_XY_VEL_MAX | 20.0 | 10.0 | m/s |
| MPC_XY_CRUISE | 12.0 | 6.0 | m/s |
| MPC_ACC_HOR_MAX | 1.5 | 0.8 | m/s² |
| MPC_THR_HOVER | 0.0 | 0.0 | -(中性浮力) |
| MPC_MAN_TILT_MAX | 15.0 | 15.0 | deg |

**注**: MIXER_FILE/MIXER_AIRMODE/MOT_NOUT 参数已在当前PX4版本移除, 不再使用。

## 13. 着陆检测参数 (LNDAS_*) @group: Land Detector

| 参数名 | 值 | 单位 | 说明 |
|--------|------|------|------|
| LNDAS_XY_VEL_MAX | 0.5 | m/s | 水平速度阈值 |
| LNDAS_Z_VEL_MAX | 0.3 | m/s | 垂直速度阈值 |
| LNDAS_ROT_MAX | 3.0 | deg/s | **三轴角速度范数**阈值(V2修复: 含yaw) |
| LNDAS_GND_PROX | 1.0 | m | 近地判定(测距仪) — **2026-08-30固件裁剪后无测距仪驱动, 此参数失效** |
| LNDAS_GND_ALT | 1.0 | m | 近地判定(无测距仪用-z) — 裁剪后此路径为主 |
| LNDAS_TOUCH_DIST | 0.3 | m | 物理触地距离 — **裁剪后physically_touched_down恒false, 此参数无效** |

**特性**: 飞艇 `landed=true` = "armed+无运动"(悬停常态), 物理触地由 physically_touched_down 单独区分; AUTO_LAND模式强制landed=true; 速度检测有1s新鲜度检查。

## 14. 安全/Failsafe参数

| 参数名 | [仿真]值 | [实飞首飞]值 | 说明 |
|--------|---------|--------------|------|
| COM_ARM_WO_GPS | 1 | **0** | 实飞必须GPS |
| COM_LOW_BAT_ACT | 0 | **1** | 实飞低电量动作 |
| NAV_RCL_ACT | 0 | **3**(返航) | 飞艇RTL实际=Altitude原地悬停 |
| NAV_DLL_ACT | 0 | **3**(返航) | 同上 |
| COM_RC_LOSS_T | 默认 | 5.0 s | |
| COM_DL_LOSS_T | 默认 | 30.0 s | 150km数传 |
| COM_DISARM_LAND | 0 | 0 | 禁用(悬停landed=true正常) |
| COM_DISARM_PRFLT | 0 | 0 | 禁用(同上) |
| COM_FAIL_ACT_T | 30 | 30 | |
| COM_ARM_IMU_ACC | 2.0 | 0.7 | |
| CBRK_SUPPLY_CHK | 894281 | 0(启用) | |

**内部failsafe(airship_att_control, 独立于Commander)**: ARMED + (RC丢失或GCS丢失, 任一即可) + 心跳超时5s → 激活, 锁定位置/高度悬停; 信号恢复即解除。不通知Commander, QGC无告警(仅console日志`[FAILSAFE]`)。

## 15. MAVLink/传感器/输出配置

见 [03_interfaces.md](03_interfaces.md) 第7节 和 [05_hardware.md](05_hardware.md) 第4/6节。

## 16. 参数前缀规范汇总

| 前缀 | 模块 | @group |
|------|------|--------|
| AS_ | airship_att_control | Airship Attitude Control |
| BALLOON_* / BLOWER_* / VALVE_* | ballast_control + ballast_output | Ballast Control |
| CA_AS_* | control_allocator(飞艇) | Control Allocation |
| LNDAS_* | land_detector | Land Detector |
| MPC_* | navigator(复用) | Multicopter Position Control |
