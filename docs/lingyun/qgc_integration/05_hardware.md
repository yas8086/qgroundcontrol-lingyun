# 05 - 实飞硬件接口与控制分配

**文档版本**: 3.0 (基于2026-08-30全量代码分析, V2架构)
**最后更新**: 2026-08-30

## 1. 飞控硬件

| 项目 | 值 |
|------|------|
| 飞控板 | 雷迅 CUAV x25-evo (Cortex-M7, **无IOMCU**) |
| 板级配置 | `boards/cuav/x25-evo/default.px4board` |
| 启动脚本 | `boards/cuav/x25-evo/init/rc.board_{defaults,mavlink,extras}` |
| 飞艇模块 | `CONFIG_MODULES_AIRSHIP_ATT_CONTROL/BALLAST_CONTROL/BALLAST_OUTPUT=y` |
| 以太网 | CONFIG_BOARD_ETHERNET=y |
| **固件裁剪** | 2026-08-30 FLASH裁剪 95.08%→87.34%(-148.5KB), 明细见 `docs/lingyun/flash_trim_record.md`; 裁剪: CAMERA_CAPTURE/DSHOT/COMMON_INS/COMMON_DISTANCE_SENSOR 全组禁用, COMMON_MAGNETOMETER→RM3100+IST8310, COMMON_DIFFERENTIAL_PRESSURE→MS4525DO |

**注意**: MC_*/FW_*/VTOL_*模块不能禁用(flight_mode_manager/sticks等库依赖其参数定义)。

**裁剪对功能的影响(QGC侧需知晓)**:
- **无测距仪驱动**: physically_touched_down 恒false(纯运动学landed判定), 近地判定走local position备用路径
- 罗盘仅RM3100(板载)+IST8310(外接)+DroneCAN(NEO3Pro), 其余11个磁力计驱动已裁
- DShot彻底从固件移除(此前仅参数禁用), 只能标准PWM/DroneCAN输出

## 2. 板级启动脚本

### 2.1 rc.board_defaults
- MAV_2(以太网CC): CONFIG=1000, BROADCAST=1, MODE=0, RATE=100000, UDP 14550
- 电池: BAT1_V_DIV=18, BAT1_A_PER_V=24; INA238/228/226禁用
- USB_MAV_MODE=5; UAVCAN_SUB_GPS/BAT=1
- IMU热控: SENS_IMU_TEMP=45, CORE_IMU_TEMP=45, `core_heater start`
- `pwm_voltage_apply start`(3.3V/5V切换), `safety_button start`

### 2.2 rc.board_mavlink
- **TELEM1(/dev/ttyS6)**: 150km数传, `mavlink start -d /dev/ttyS6 -b 57600 -r 50000 -m p:MAV_1_MODE -x -z`(限速50kbps防链路过载)
- Ethernet由rc.serial自动启动

### 2.3 rc.board_extras
- UAVCAN: `UAVCAN_ENABLE>0`时`uavcan_node start`(CAN1自动发现NEO3Pro)
- 空速计: SENS_EN_ASPD=1触发rc.serial自动启动
- UXRCE-DDS: UXRCE_DDS_CFG>-1时启动(ROS2, 可选)

## 3. 传感器配置

| 设备 | 型号 | 接口 | 关键参数 |
|------|------|------|---------|
| GPS | CUAV NEO3 Pro | **CAN1(DroneCAN)** | GPS_1_PROTOCOL=2, SENS_GPS_MASK=3, UAVCAN_ENABLE=1 |
| 空速计 | CUAV SKYE2(MS4525DO) | **I2C4(EXT2)** | SENS_EN_ASPD=1, ASPD_PRIMARY=1, SENS_ARSPD_CFG=4, ASPD_TYPE=2; 裁剪后仅ms4525do专用驱动(其余差压驱动已裁) |
| 罗盘 | RM3100(板载)+IST8310(外接)+DroneCAN(NEO3Pro内置) | I2C+CAN | SYS_HAS_MAG=1; 裁剪后仅这3个罗盘源(其余11个磁力计驱动已裁) |
| IMU热控 | - | - | 45°C目标温度 |

**注**: 测距仪驱动全组已裁(无硬件), 依赖dist_bottom的功能(land_detector物理触地检测)不可用, 近地判定退化为local position的-z路径(LNDAS_GND_ALT=1m)。

## 4. PWM输出映射(V2, 实飞2058_lingyun01)

### 4.1 MAIN端口: 10电机 (PWM_MAIN_FUNC1-10 = 101-110)

| 通道 | FUNC | 电机 | 说明 |
|------|------|------|------|
| MAIN1-4 | 101-104 | 上升电机M0-M3(左前/右前/左后/右后) | 四角布局 |
| MAIN5-6 | 105-106 | 下降电机M4-M5(前/后) | 中轴布局 |
| MAIN7-10 | 107-110 | 推进电机M6-M9(左前/右前/左后/右后) | 四角, 可反转 |

- PWM范围: DIS=1500, MIN=1000, MAX=2000 (标准PWM; 电机最终走DroneCAN/PWM待布线裁决)
- **可反转电机**(CA_R_REV=0x3FF): 负输出映射为反转转速

### 4.2 AUX端口: 浮力4囊8通道 (PWM_AUX_FUNC1-8 = 201-208)

| 通道 | FUNC | 执行器 | 值域 |
|------|------|--------|------|
| AUX1 | 201(Servo1) | 囊1(左主)风机 | 连续0-1(占空比) |
| AUX2 | 202 | 囊1阀门 | 二值0/1(24V经MOS/继电器板) |
| AUX3-4 | 203-204 | 囊2(右主)风机/阀门 | 同上 |
| AUX5-6 | 205-206 | 囊3(左副)风机/阀门 | 同上 |
| AUX7-8 | 207-208 | 囊4(右副)风机/阀门 | 同上 |

- **PWM_AUX_DIS=1000**(未解锁/超时→断电, 常闭阀安全关闭); MIN=1000, MAX=2000, 50Hz
- 电气约定: ≤1200μs判关, ≥1800μs判开(驱动板容错区)
- **x25-evo实飞警告**: 无IOMCU, 真机pwm_out用PWM_MAIN前缀, **PWM_AUX_*参数在真机静默失效**; ballast 8通道迁移PWM_MAIN(电机走DroneCAN腾通道)方案见 `test/airship_test/BALLAST_HW_INTERFACE_DECISION.md`

## 5. 控制分配(ActuatorEffectivenessCustom, V2)

**文件**: `src/modules/control_allocator/VehicleActuatorEffectiveness/ActuatorEffectivenessCustom.cpp` (410行)
**架构**: 效率矩阵仅用于Custom框架校验, **updateSetpoint完全手工覆盖式分配**(非求解器)。

### 5.1 输入输出

| control_sp索引 | 含义 | 输出索引 | 执行器 |
|---|---|---|---|
| (0) torque_x | 横滚力矩 | (0-3) | 上升电机M0-M3 [0,1] |
| (1) torque_y | 俯仰力矩(正=抬头) | (4-5) | 下降电机M4-M5 [0,1] |
| (2) torque_z | 偏航力矩 | (6-9) | 推进电机M6-M9 **[-0.6,+0.6]** |
| (3) thrust_x | 前进推力 | | |
| (5) thrust_z | 垂直推力(**负=上升/正=下降**) | | |

### 5.2 分配算法七段

1. **PropTest旁路**: ACRO+ARMED+CA_AS_PT_EN=1 → 仅单侧推进
2. **飞行模式硬开关**: AUTO_TAKEOFF/AUTO_LAND → 推进禁用; 悬停判定 `thrust_x<0.01 && |torque_z|<0.01`(V4: 有转向需求仍进推进分配, 支持纯差动原地转向)
3. **推进分配**: forward=constrain(thrust_x,0,PROP_MAX); yaw_diff=constrain(torque_z*0.8,±0.6); left=forward+yaw_diff, right=forward-yaw_diff
4. **垂直二选一**: thrust_z<-0.01→上升组 / >0.01→下降组(互斥防对冲)
5. **横滚差动**: roll_diff=constrain(torque_x*0.5,±0.3), 左组增右组减(力臂PY≈6.34m)
6. **俯仰差动+推进补偿**: pitch_delta=constrain(torque_y*0.5,±0.5); 补偿 `comp = PZ_PROP*4*K_PROP*forward² / (K_LUP*(PX_FRONT+PX_REAR))`, 限幅[0,1.0]
7. **力臂反比加权+三分支合成**: 上升组front_weight=2*PX_REAR/(PX_FRONT+PX_REAR)≈1.456, rear≈0.544(消除满推净低头力矩~1018N·m); 下降组硬编码6.957/11.443m→front=1.244x, rear=0.756x; 悬停分支差动限幅±0.15(单向升力电机防净升力漂移)

**注意**: 旧文档描述的"悬停前部电机优先方案"在V2代码中**已不存在**, 当前是前后组对称差动+限幅。

## 6. 着陆检测(AirshipLandDetector)

- **核心思想**: 飞艇空中悬停是常态, `armed+无运动`即landed=true(保EKF2 ZUPT/ZGUPT激活); 物理触地由physically_touched_down单独区分(**2026-08-30固件裁剪后无测距仪, 该字段恒false**)
- 判据: 无水平运动(XY_VEL 0.5m/s) && 无垂直运动(Z_VEL 0.3m/s) && 无旋转(**三轴范数** ROT_MAX 3°/s, V2修复含yaw); 速度数据超1s视为"无运动"
- 近地判定: 无测距仪时走local position备用路径(-z < LNDAS_GND_ALT=1m); close_to_ground_skipped_check=1标识跳过测距仪路径
- AUTO_LAND模式强制landed=true
- 与多旋翼差异: 不看油门/姿态; 无迟滞因子
- 实飞配套: COM_DISARM_LAND=0, COM_DISARM_PRFLT=0(防误disarm)

## 7. 仿真桥接(GZBridge)

| 链路 | 接口 | 说明 |
|------|------|------|
| 电机 | gz话题 `/{model}/command/motor_speed` (gz::msgs::Actuators) | MixingOutput消费actuator_motors; 前3秒静默; esc_status的esc_rpm=归一化速度非真实RPM |
| 浮力 | `/{model}/ballast_cmd`(Vector3d: x=net_buoyancy) + `/{model}/ballast_actuator`×4(x=囊索引, y=位图bit0风机/bit1阀门, z=质量kg) | GZMixingInterfaceBallast, 10Hz |
| 传感器 | IMU/气压/GPS/磁力计/空速等(SIM_GZ_EN_*控制) | 标准链路 |

## 8. 气动仿真插件(AirshipDynamics)

**文件**: `Tools/simulation/gz/plugins/airship_dynamics/AirshipDynamics.cc` (676行)
每帧七步: ①动态浮力(基准+ballast_cmd, 浮力中心(0,0,-1.0)比重心高0.5m→摆锤稳定) ②四囊质量计入惯量(平行轴) ③Munk力矩/附加质量(Kirchhoff方程, m11=187/m22=1496/m33=787) ④粘性力/力矩(迎角函数) ⑤轴向阻力(C=30三轴) ⑥旋转阻尼(45000/220000/30000) ⑦合力合成。
**订阅**: /world/{w}/wind, /model/{m}/ballast_cmd, /model/{m}/ballast_actuator。

## 9. 仿真与实飞差异

| 项目 | 仿真 | 实飞 |
|------|------|------|
| 机型文件 | init.d-posix/2058_gz_lingyun01 | ROMFS/.../2058_lingyun01 |
| 控制分配几何 | 相同(CA_ROTOR0-9与SDF一一对应) | 相同 |
| BLWR_FLOW | 0.5(加速调试) | 0.102 |
| PID | 完整调好值(AS_YR_P=2.0, YAW_TMAX=0.8) | 首飞减半(AS_YR_P=0.25, YAW_TMAX=0.2) |
| COM_ARM_WO_GPS | 1 | 0 |
| NAV_RCL/DLL_ACT | 0 | 3(RTL→飞艇Altitude悬停) |
| CBRK_SUPPLY_CHK | 894281(跳过) | 0(启用) |
| 输出 | gz_bridge直通 | PWM MAIN(电机)+AUX(ballast, 真机待迁移) |
| COM_ARM_IMU_ACC | 2.0 | 0.7 |
