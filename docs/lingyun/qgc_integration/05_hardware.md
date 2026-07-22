# 05 - 实飞硬件接口

## 1. 飞控硬件

| 项目 | 值 |
|------|------|
| 飞控板 | 雷迅 CUAV x25-evo |
| 架构 | Cortex-M7 (arm-none-eabi) |
| 以太网 | 启用 (CONFIG_BOARD_ETHERNET=y) |
| 文档链接 | https://doc.cuav.net/controller/x25/zh-hans/ |
| 板级配置 | `boards/cuav/x25-evo/default.px4board` |
| 启动脚本 | `boards/cuav/x25-evo/init/rc.board_*` |

---

## 2. 飞艇专用模块启用

**代码位置**: `boards/cuav/x25-evo/default.px4board` L48-51

```kconfig
CONFIG_MODULES_AIRSHIP_ATT_CONTROL=y    # 飞艇姿态控制
CONFIG_MODULES_BALLAST_CONTROL=y        # 浮力调节
CONFIG_MODULES_BALLAST_OUTPUT=y         # 浮力输出桥接
```

**注意**: MC_*/FW_*/VTOL_* 模块不能禁用,因为 flight_mode_manager/sticks 等库依赖它们的参数定义。

---

## 3. 板级启动脚本

### 3.1 启动顺序

```
rcS → rc.board_defaults → rc.board_mavlink → rc.board_extras
```

### 3.2 rc.board_defaults

**文件**: `boards/cuav/x25-evo/init/rc.board_defaults`

| 参数 | 值 | 说明 |
|------|------|------|
| MAV_2_CONFIG | 1000 | Ethernet端口(Companion Computer) |
| MAV_2_BROADCAST | 1 | 广播模式 |
| MAV_2_MODE | 0 | Custom模式 |
| MAV_2_RATE | 100000 | 100kB/s |
| MAV_2_REMOTE_PRT | 14550 | 远程UDP端口 |
| MAV_2_UDP_PRT | 14550 | 本地UDP端口 |
| BAT1_V_DIV | 18 | 电池电压分压比 |
| BAT1_A_PER_V | 24 | 电池电流换算 |
| SENS_EN_INA238 | 0 | 禁用INA238电源监控 |
| SENS_EN_INA228 | 0 | 禁用INA228电源监控 |
| SENS_EN_INA226 | 0 | 禁用INA226电源监控 |
| USB_MAV_MODE | 5 | USB MAVLink模式 |
| UAVCAN_SUB_GPS | 1 | 订阅UAVCAN GPS |
| UAVCAN_SUB_BAT | 1 | 订阅UAVCAN电池 |
| SENS_EN_THERMAL | 1 | 启用IMU热控 |
| SENS_IMU_TEMP | 45 | IMU目标温度45°C |
| CORE_IMU_TEMP | 45 | CUAV核心板IMU温度45°C |

**启动命令**:
- `core_heater start` - 启动核心板IMU加热
- `pwm_voltage_apply start` - 应用PWM电压(3.3V/5V)
- `safety_button start` - 启动安全按钮

### 3.3 rc.board_mavlink

**文件**: `boards/cuav/x25-evo/init/rc.board_mavlink`

**TELEM1 (/dev/ttyS6)**:
- 用途: 150km数传模块
- 波特率: 57600bps
- 速率限制: 50000 bps (`-r 50000`,150km链路带宽有限)
- 模式: 由 `MAV_1_MODE` 参数控制(默认Normal=1)
- 启用FTP: `-x`
- 启用流控: `-z`

```bash
mavlink start -d /dev/ttyS6 -b 57600 -r 50000 -m p:MAV_1_MODE -x -z
```

**Ethernet (Companion Computer)**:
- 由 `rc.serial` 自动启动 (MAV_2_CONFIG=1000)
- 无需额外配置

### 3.4 rc.board_extras

**文件**: `boards/cuav/x25-evo/init/rc.board_extras`

**UAVCAN/CAN总线设备** (CAN1):
- 启动条件: `UAVCAN_ENABLE > 0`
- 命令: `uavcan_node start`
- 自动发现CAN总线传感器 (NEO3Pro GPS等)

**空速计** (SKYE2):
- 由 `SENS_EN_ASPD=1` 触发 `rc.serial` 自动启动
- 无需额外命令

**UXRCE-DDS客户端** (可选,ROS2):
- 启动条件: `UXRCE_DDS_CFG > -1`
- 命令: `uxrce_dds_client start -t p:UXRCE_DDS_DOMAIN_ID`

---

## 4. 传感器配置

### 4.1 GPS (CUAV NEO3 Pro)

| 项目 | 值 |
|------|------|
| 型号 | CUAV NEO3 Pro |
| 接口 | CAN1总线 |
| 协议 | DroneCAN (GPS_1_PROTOCOL=2) |
| 文档链接 | https://doc.cuav.net/gps/neo-series-gnss/zh-hans/neo-3-pro.html |
| 双GPS切换 | SENS_GPS_MASK=3 |
| UAVCAN_ENABLE | 1 (仅传感器) |
| 不占用串口 | TELEM1/TELEM2留给数传和CC |

### 4.2 空速计 (CUAV SKYE2)

| 项目 | 值 |
|------|------|
| 型号 | CUAV SKYE2 |
| 芯片 | MS4525DO |
| 接口 | I2C4 (EXT2端口) |
| 文档链接 | https://doc.cuav.net/others/skye/zh-hans/skye2.html |
| SENS_EN_ASPD | 1 (启用驱动) |
| ASPD_PRIMARY | 1 (作为主空速源) |
| SENS_ARSPD_CFG | 4 (I2C4) |
| ASPD_TYPE | 2 (MS4525) |

### 4.3 IMU热控

| 项目 | 值 |
|------|------|
| 主IMU温度 | 45°C (SENS_IMU_TEMP) |
| 核心板IMU温度 | 45°C (CORE_IMU_TEMP) |
| 启动命令 | `core_heater start` |
| SENS_EN_THERMAL | 1 |

### 4.4 罗盘

| 项目 | 值 |
|------|------|
| SYS_HAS_MAG | 1 (启用) |
| 用途 | EKF2航向初始化 |

### 4.5 气压计

| 项目 | 值 |
|------|------|
| SENS_BARO_QNH | 1013.25 |

---

## 5. 通信接口

### 5.1 数传模块 (TELEM1)

| 项目 | 值 |
|------|------|
| 端口 | TELEM1 (/dev/ttyS6) |
| MAV_1_CONFIG | 101 |
| 波特率 | 57600 bps (MAV_1_BAUD) |
| MAV_1_MODE | 1 (Normal) |
| MAV_1_RADIO_CTL | 0 (禁用MAVLink无线电控制) |
| 速率限制 | 50000 bps (150km链路带宽) |
| 数传模块 | 自主设计150km数传 |

### 5.2 Companion Computer (以太网)

| 项目 | 值 |
|------|------|
| 端口 | Ethernet (MAV_2_CONFIG=1000) |
| MAV_2_BAUD | 0 (以太网不需要波特率) |
| MAV_2_MODE | 0 (Custom) |
| MAV_2_RATE | 100000 (100kB/s) |
| MAV_2_UDP_PRT | 14550 |
| MAV_2_REMOTE_PRT | 14550 |
| MAV_2_BROADCAST | 1 |
| 用途 | 视觉定位、路径规划、避障 |

### 5.3 USB MAVLink

| 项目 | 值 |
|------|------|
| USB_MAV_MODE | 5 |
| 用途 | 地面配置、固件升级 |

### 5.4 UXRCE-DDS (可选,ROS2)

| 项目 | 值 |
|------|------|
| 配置参数 | UXRCE_DDS_CFG |
| 域ID | UXRCE_DDS_DOMAIN_ID |
| 用途 | Companion Computer通过ROS2通信 |

---

## 6. PWM输出映射

### 6.1 MAIN端口 (8电机,标准PWM)

| 通道 | PWM_FUNC | 电机 | PWM范围(μs) |
|------|---------|------|------------|
| MAIN1 | 101 (Motor 1) | 升力电机M0(前1,上升) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN2 | 102 (Motor 2) | 升力电机M1(前2,下降) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN3 | 103 (Motor 3) | 升力电机M2(后1,下降) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN4 | 104 (Motor 4) | 升力电机M3(后2,上升) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN5 | 105 (Motor 5) | 推进电机M4(左前LF) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN6 | 106 (Motor 6) | 推进电机M5(左后LB) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN7 | 107 (Motor 7) | 推进电机M6(右前RF) | DIS=1500, MIN=1000, MAX=2000 |
| MAIN8 | 108 (Motor 8) | 推进电机M7(右后RB) | DIS=1500, MIN=1000, MAX=2000 |

**注**: 标准PWM接口,禁用DShot协议。

### 6.2 AUX端口 (鼓风机+阀门,标准PWM 50Hz)

**当前配置(旧方案,仅4通道)**:

| 通道 | PWM_FUNC | 设备 | PWM范围(μs) |
|------|---------|------|------------|
| AUX1 | 201 (Servo 1) | 左鼓风机 | DIS=1500, MIN=1000, MAX=2000 |
| AUX2 | 202 (Servo 2) | 右鼓风机 | DIS=1500, MIN=1000, MAX=2000 |
| AUX3 | 203 (Servo 3) | 左阀门 | DIS=1500, MIN=1000, MAX=2000 |
| AUX4 | 204 (Servo 4) | 右阀门 | DIS=1500, MIN=1000, MAX=2000 |

**已知限制**: 当前ballast_output模块只映射4个旧字段,不支持四气囊16个执行器(8风机+8阀门)。
actuator_servos只有8个通道(NUM_CONTROLS=8),四气囊需要16个执行器,实飞硬件PWM通道分配方案待确认。

**四气囊目标配置(待实飞验证)**:
- 4个空气囊: LI(右内), LO(右外), RI(左内), RO(左外)
- 每个气囊4个执行器: 充气风机 + 抽气风机 + 充气阀门 + 放气阀门
- 总计16个执行器,需要扩展PWM通道或使用IO协处理器

**输出路径**:
```
ballast_control (PID) → ballast_setpoint (uORB)
                            ↓
                      ballast_output (订阅)
                            ↓
                      actuator_servos (uORB)
                            ↓
                      FunctionServos (订阅)
                            ↓
                      PWM_AUX1-4 (硬件输出,当前仅4通道)
```

---

## 7. 控制分配配置

### 7.1 控制分配参数

| 参数 | 值 | 说明 |
|------|------|------|
| CA_AIRFRAME | 9 | Custom (X+Z混合推力) |
| CA_ROTOR_COUNT | 8 | 8电机 |
| CA_METHOD | 0 | 控制分配方法 |
| CA_SV_CS_COUNT | 0 | **无舵机**(新方案) |
| CA_R_REV | 255 | 所有电机可逆映射 |

### 7.2 升力电机配置 (CA_ROTOR0-3)

| 电机 | PX | PY | PZ | AX | AY | AZ | CT | KM |
|------|----|----|----|----|----|----|----|----|
| M0(前1) | 11.237 | 0 | -0.340 | 0 | 0 | **-1** | 0.1106 | 1 |
| M1(前2) | 9.227 | 0 | -0.340 | 0 | 0 | **+1** | 0.2212 | -1 |
| M2(后1) | -13.523 | 0 | -0.340 | 0 | 0 | **+1** | 0.2212 | -1 |
| M3(后2) | -15.513 | 0 | -0.340 | 0 | 0 | **-1** | 0.1106 | 1 |

**AZ说明**:
- `AZ=-1`: 推力向上(上升电机,M0/M3)
- `AZ=+1`: 推力向下(下降电机,M1/M2)

### 7.3 推进电机配置 (CA_ROTOR4-7)

| 电机 | PX | PY | PZ | AX | AY | AZ | CT | KM |
|------|----|----|----|----|----|----|----|----|
| M4(LF) | 2.559 | -5.281 | 1.503 | 1 | 0 | 0 | 1.0 | 0.05 |
| M5(LB) | -2.535 | -5.281 | 1.503 | 1 | 0 | 0 | 1.0 | -0.05 |
| M6(RF) | 2.559 | 5.293 | 1.503 | 1 | 0 | 0 | 1.0 | 0.05 |
| M7(RB) | -2.535 | 5.293 | 1.503 | 1 | 0 | 0 | 1.0 | -0.05 |

**KM说明**:
- M4/M6: KM=+0.05 (CCW)
- M5/M7: KM=-0.05 (CW)
- 反扭矩前后对称抵消

---

## 8. 控制分配逻辑(ActuatorEffectivenessCustom)

**代码位置**: `src/modules/control_allocator/VehicleActuatorEffectiveness/ActuatorEffectivenessCustom.cpp`

### 8.1 输入输出

**输入** (control_sp向量):
- `control_sp(1)` = torque_y (俯仰力矩)
- `control_sp(2)` = torque_z (偏航力矩)
- `control_sp(3)` = thrust_x (水平推力)
- `control_sp(5)` = thrust_z (垂直推力)

**输出** (actuator_sp向量):
- `actuator_sp(0-3)` = 升力电机M0-M3 [0,1]
- `actuator_sp(4-7)` = 推进电机M4-M7 [0,1]

### 8.2 起飞/悬停模式检测

```c
bool takeoff_hover_mode = (thrust_x < 0.01f);
```

- 起飞/悬停模式: 推进电机关闭,跳过推进-俯仰耦合
- 飞行模式: 推进电机工作,根据torque_y调节forward

### 8.3 推进-俯仰耦合补偿

推进电机在重心下方,向前推产生抬头力矩:
- `T_pitch_prop = PZ_PROP * 4 * K_PROP * forward²`
- 用M1(前部下降) + M3(后部上升)产生低头力矩抵消
- 净推力=0: `K_LIFT_DOWN * comp_m1 = K_LIFT_UP * comp_m3`
- `comp_m3 = 2 * comp_m1` (因为K_LIFT_DOWN = 2*K_LIFT_UP)

### 8.4 悬停模式前部电机优先方案

| 俯仰需求 | 前部电机 | 后部电机 |
|---------|---------|---------|
| 抬头(小) | M0(上升) | 关闭 |
| 抬头(大) | M0(上升) | M2(下降)辅助 |
| 低头(小) | M1(下降) | 关闭 |
| 低头(大) | M1(下降) | M3(上升)辅助 |
| 推进抬头补偿 | M1(下降) | M3(上升) |

**优点**: 节省后部电机能耗,前部电机力矩足够(M1最大低头力矩4011N·m)

---

## 9. Failsafe配置(实飞)

### 9.1 RC失效保护

| 参数 | 值 | 说明 |
|------|------|------|
| NAV_RCL_ACT | 3 | RC丢失返航 |
| COM_RC_IN_MODE | 0 | RC优先模式 |
| COM_RC_LOSS_T | 5.0 | RC丢失超时5秒 |
| COM_RCL_EXCEPT | 4 | RC丢失后保持Position模式 |

### 9.2 数据链失效保护

| 参数 | 值 | 说明 |
|------|------|------|
| NAV_DLL_ACT | 3 | 数据链丢失返航 |
| COM_DL_LOSS_T | 30.0 | 数据链丢失超时30秒(150km链路) |

### 9.3 低电量失效保护

| 参数 | 值 | 说明 |
|------|------|------|
| COM_LOW_BAT_ACT | 1 | 低电量自动降落 |

### 9.4 Failsafe动作超时

| 参数 | 值 | 说明 |
|------|------|------|
| COM_FAIL_ACT_T | 30 | 30秒后执行failsafe动作(飞艇响应慢) |

### 9.5 解锁后/着陆后处理

| 参数 | 值 | 说明 |
|------|------|------|
| COM_DISARM_LAND | 0 | 着陆后不自动disarm(中性浮力,landed=true正常) |
| COM_DISARM_PRFLT | 0 | ARM后未起飞不disarm |
| COM_ARM_WO_GPS | 0 | 必须GPS锁定才能解锁(实飞) |

---

## 10. 仿真与实飞差异

| 项目 | 仿真 | 实飞 |
|------|------|------|
| 机型配置 | 2058_lingyun01 (相同) | 2058_lingyun01 |
| 飞控硬件 | Gazebo Harmonic | 雷迅x25-evo |
| GPS | 仿真GPS | CUAV NEO3 Pro (CAN) |
| 空速计 | 仿真 | CUAV SKYE2 (I2C) |
| 数传 | 无需 | 150km数传 (TELEM1, 57600bps) |
| Companion Computer | 无需 | 以太网 |
| COM_ARM_WO_GPS | 1 (允许无GPS) | 0 (必须GPS) |
| NAV_RCL_ACT | 0 (禁用) | 3 (返航) |
| NAV_DLL_ACT | 0 (禁用) | 3 (返航) |
| COM_LOW_BAT_ACT | 0 (禁用) | 1 (自动降落) |
| CBRK_SUPPLY_CHK | 894281 (禁用) | (默认,启用) |
| COM_ARM_IMU_ACC | 2.0 (放宽) | 0.7 (默认) |
| PID参数 | 完整调好值 | 首飞减半值 |
| EKF2检查 | 放宽 | 默认+实飞校准 |
