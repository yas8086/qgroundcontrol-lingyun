# 06 - QGC开发要点

**文档版本**: 3.1 (2026-08-30全量代码分析V2架构 + 固件裁剪影响补充)
**最后更新**: 2026-08-30

## 1. 飞艇识别与模式UI

### 1.1 识别
QGC通过 `HEARTBEAT.type == 7 (MAV_TYPE_AIRSHIP)` 识别飞艇, 启用飞艇专属UI。

### 1.2 模式按钮与映射(含V2变化)

| QGC按钮 | custom_mode(main,sub) | 飞艇行为 | 启用条件 |
|---------|----------------------|---------|---------|
| Manual | (1,0) | 摇杆直映射(pitch杆双职能) | 始终 |
| **Acro** | (5,0) | **PropTest单侧推进测试**(需CA_AS_PT_EN=1, 平时无特殊行为) | 地面测试用 |
| Stabilized | (7,0) | yaw锁定+俯仰角控制 | 始终 |
| Altitude | (2,0) | 定高+摇杆调高+悬停转向 | 始终 |
| Position | (3,0) | L1导引定点 | GPS锁定 |
| Takeoff | (4,2) | Settle→Climb→Hold→自动切Loiter | **ARMED + 已解锁时需完整local_position(canRun)** |
| Land | (4,6) | 分阶段下降→3m自动强制DISARM | **总是可切入(force=true)** |
| Mission | (4,4) | Task航点(LOITER占位跳过) | 任务已上传 |
| Loiter | (4,3) | =Altitude悬停 | - |
| RTL | (4,5) | **=Altitude原地悬停(不飞回home!)** | - |

### 1.3 QGC须知的关键行为差异(相对多旋翼)
1. **RTL不返航**: 飞艇RTL=原地定高悬停(detectMode把AUTO_RTL映射为Altitude)。QGC的RTL按钮语义完全不同, 建议飞艇UI标注"悬停等待"
2. **Takeoff被拒无提示**: alt>=AS_TAKEOFF_ALT时PX4_WARN只进console, QGC界面无反馈。建议QGC在发TAKEOFF前自查: `relative_alt >= AS_TAKEOFF_ALT参数值`则提示"当前高度过高"
3. **降落自动disarm**: Land到3m自动强制DISARM(21196), QGC会看到突然disarm, 属正常
4. **起飞完成自动切Loiter**: QGC看到模式从Takeoff变Loiter, 属正常(非用户操作)
5. **landed=true是常态**: 空中悬停landed=true, EXTENDED_SYS_STATE的landed_state不能当"在地面"解读
6. **无测距仪(固件裁剪)**: physically_touched_down恒false, landed纯运动学判定(速度+角速度); QGC不应依赖EXTENDED_SYS_STATE区分"悬停"与"触地", 二者在飞艇上语义等价

## 2. 浮力系统监控(QGC独有能力)

### 2.1 NAMED_VALUE_FLOAT数据源
ballast_control轮转发布5个字段(每字段约10Hz):

| key | 含义 | QGC建议UI |
|-----|------|----------|
| buoy | 净浮力(N), 正=升力需求 | 浮力仪表(±500N量程) |
| alt_err | 高度误差(m) | 目标vs当前高度差指示 |
| b_mass | 单囊空气质量(kg, 0-128.5) | 气囊充气量条形图 |
| blower | 风机占空比(0-255) | 风机状态灯+强度条 |
| valve | 阀门开关(0/255) | 阀门状态灯 |

### 2.2 建议浮力面板
- 净浮力箭头(上升/下降/平衡)
- 气囊质量条(b_mass/128.5)
- 风机/阀门执行状态
- 高度误差带
- **超压告警**: >4.75kPa时PX4有console告警但QGC无感知; 可用b_mass>M_MAX*95%近似推断

## 3. Failsafe状态感知(有限)

| 层 | 触发 | QGC可见性 |
|----|------|----------|
| Commander层 | RC/DLL丢失→RTL | HEARTBEAT.system_status=CRITICAL + STATUSTEXT + 模式变RTL |
| **airship_att_control内部层** | RC或GCS任一丢失+5s | **仅console日志`[FAILSAFE]`, QGC无告警**(模式显示不变, 因detectMode的Failsafe不反映到nav_state) |
| ballast紧急排气 | failsafe标志或链路丢失5s | 无直接提示(可从buoy/b_mass变化推断) |

**建议**: QGC监控HEARTBEAT的system_status + 位置是否长时间静止(悬停保护特征)来增强告警。

## 4. 参数界面(V2分组)

### 4.1 推荐页面结构
1. **飞艇姿态控制** (@group Airship Attitude Control)
   - 高度PID: AS_ALT_P/I/D/IMAX/VMAX/VFF/SRATE + AS_ALT_MAX/MIN/SOFT
   - 俯仰PID: AS_PIT_*/AS_PR_* + AS_PIT_FF
   - 偏航PID: AS_YAW_*/AS_YR_* + AS_YAW_TMAX
   - **横滚PID(V2新增)**: AS_ROLL_*/AS_RR_*
   - 起飞: AS_TAKEOFF_ALT/TKF_HOLD_T/TKF_ALT_TOL/TAKEOFF_RAMP/**TKF_VMAX**
   - 降落: AS_LND_DONE_ALT/VHI/VMID/VLO/VGND
   - 位置: AS_POS_XY_*/AS_VEL_XY_*
   - 测试调参(高级): AS_TST_*/AS_AT_*
2. **浮力控制** (@group Ballast Control)
   - 控制: BALLOON_AST_EN/DEADZONE/P/I/D/I_MAX/RATE_MAX
   - 硬件: BALLOON_M_MAX/BLWR_FLOW/VALVE_FLOW_MAX/BLOWER_TAU/VALVE_OPEN_DELAY
   - 互锁: BALLOON_MIN_ON/BALLOON_SWT_GD
   - 安全: BALLOON_EMG_EN + BALLOON_OUT_EN
   - **注意: BALLOON_THRSHLD是死参数, 建议UI标注或不显示; TRIM_BALLOON_*已删除勿展示**
3. **控制分配** (@group Control Allocation, 建议只读)
   - 物理常数: CA_AS_K_LUP/LDN/PROP/PZ_PROP/PX_FRONT/PX_REAR
   - 限位: CA_AS_PROP_MAX
   - PropTest: CA_AS_PT_EN/SIDE/THR
4. **Land Detector**: LNDAS_*
5. **安全**: COM_*/NAV_RCL_ACT/NAV_DLL_ACT

### 4.2 参数预设(场景化)
| 预设 | 来源 | 特征 |
|------|------|------|
| 仿真调试 | rc.lingyun01_defaults | 全PID(AS_YR_P=2.0, YAW_TMAX=0.8), failsafe禁用 |
| 实飞首飞 | 2058_lingyun01实飞段 | PID减半(AS_YR_P=0.25, YAW_TMAX=0.2), failsafe启用, 强制GPS |

## 5. 虚拟摇杆(V2杆法)

**按模式区分提示**(QGC需动态显示):

| 模式 | Throttle | Pitch杆 | Roll杆 | Yaw杆 |
|------|----------|---------|--------|-------|
| Manual | 前进推力 | 俯仰角±15°**兼**升降速度 | 偏航速率 | (未用) |
| Stable | 前进推力 | 升降速度 | 偏航速率 | **俯仰角±15°** |
| Altitude | 前进(pitch杆) | 前进推力 | 偏航速率 | 俯仰角±15° |
| Altitude油门 | **高度调节**(中位死区) | | | |

Manual/Stable的pitch杆职能完全不同, QGC虚拟摇杆标签必须按当前模式切换。

## 6. 任务规划(V2)

| 航点类型 | 飞艇行为 | QGC建议 |
|---------|---------|---------|
| Takeoff | 垂直爬升到param7或AS_TAKEOFF_ALT | 仅高度参数 |
| Waypoint | L1导引, yaw指向目标 | 间距>50m, 单次转向<30°(S形拆分) |
| **Loiter(任务中)** | **会被跳过**: current==LOITER且next==POSITION时直接取next | 避免用LOITER做"爬升后平飞"设计 |
| Land | 分阶段垂直下降(1.5/1.0/0.5/0.2m/s)→3m自动disarm | 设置漂移容差区 |
| DO_CHANGE_ALTITUDE | 支持, param1(AGL)→全局目标 | 可用作任务中改高 |

## 7. Offboard接口约定

见[03_interfaces.md](03_interfaces.md)第6节。要点:
- SET_ATTITUDE_TARGET: `body_roll_rate`字段承载推进油门(0-1), `thrust`承载升降(-1~1), 四元数承载pitch/yaw; `body_pitch_rate`已废弃
- 500ms断流→安全悬停(非多旋翼的failsafe行为)
- 需MAV_FWDEXTSP=1 + 持续流(1s内)+ 解锁 + canRun

## 8. HUD建议(V2)

| 指示器 | 数据源 |
|--------|--------|
| 浮力仪表 | NAMED_VALUE_FLOAT(buoy/b_mass/blower/valve) |
| 起飞进度 | 模式=Takeoff + relative_alt vs AS_TAKEOFF_ALT(Settle/Climb阶段推断) |
| 降落阶段 | 模式=Land + relative_alt(>10/5-10/2-5/<2对应VHI/VMID/VLO/VGND) |
| 推进电机状态 | ACTUATOR_OUTPUT_STATUS通道7-10; **Takeoff/Land模式应显示OFF** |
| 10电机输出 | ACTUATOR_OUTPUT_STATUS(通道1-10; 注意可反转通道值域) |
| RTL语义 | 模式=RTL时标注"悬停等待"而非"返航中" |

## 9. 起飞前检查清单(V2)

- [ ] alt_agl < AS_TAKEOFF_ALT(20m) — 否则TAKEOFF被静默拒绝
- [ ] GPS/local_position有效(**已解锁状态AUTO_TAKEOFF需完整local_position**, 否则COMMAND_ACK: TEMPORARILY_REJECTED)
- [ ] AS_TAKEOFF_ALT/AS_ALT_MAX/MIN设置合理
- [ ] BALLOON_AST_EN=1且b_mass正常
- [ ] CA_AS_PROP_MAX/AS_YAW_TMAX为预期预设值(仿真值vs实飞值)
- [ ] IMU温度45°C(x25-evo热控)

## 10. 常见问题(V2更新)

### Q1: 显示"未知飞行模式"?
模式映射纯标准(px4_custom_mode), 检查QGC对PX4_CUSTOM_SUB_MODE_AUTO_TAKEOFF(2)/LAND(6)支持; PropTest显示为Acro。

### Q2: TAKEOFF命令被拒(COMMAND_ACK: TEMPORARILY_REJECTED)?
已解锁时AUTO_TAKEOFF要求完整local_position(旋翼要求)。检查GPS/EKF; 未解锁时可切(但激活后EKF无效会failsafe降级)。

### Q3: TAKEOFF命令被ACCEPTED但飞艇不动?
可能alt>=AS_TAKEOFF_ALT被AirshipControl拒绝(仅console日志), 或处于Settle阶段(前5s保持当前高度属正常)。

### Q4: RTL后飞艇不回家?
设计如此: 飞艇RTL=原地Altitude悬停(中性浮力艇的failsafe行为)。

### Q5: Land完成后突然disarm?
设计如此: 到达AS_LND_DONE_ALT(3m)自动强制DISARM。

### Q6: 浮力参数BALLOON_THRSHLD修改无效?
死参数(V2遗留, 代码零引用)。V2充/排决策仅看净浮力符号+互锁状态机。

### Q7: TRIM_BALLOON参数找不到了?
V2已删除(四囊同步架构, 气囊不参与横滚; 横滚由上升电机左右差动闭环AS_ROLL_*/AS_RR_*负责)。

### Q8: 实机PWM_AUX通道(鼓风机/阀门)无输出?
x25-evo无IOMCU, PWM_AUX_*参数真机静默失效, 需按`test/airship_test/BALLAST_HW_INTERFACE_DECISION.md`迁移PWM_MAIN。

### Q9: Offboard下发thrust后飞艇停推?
thrust_x映射到body_roll_rate字段(pymavlink兼容方案); 检查type_mask位与持续流(500ms新鲜度)。

### Q10: 实飞PID与仿真PID不一致?
设计如此(首飞减半策略)。QGC可提供两套预设, 见[02_parameters.md](02_parameters.md)第4.2节。

## 11. 参考资源

- PX4: https://docs.px4.io/ | QGC: https://docs.qgroundcontrol.com/ | MAVLink: https://mavlink.io/
- CUAV x25-evo: https://doc.cuav.net/controller/x25/zh-hans/
- CUAV NEO3 Pro: https://doc.cuav.net/gps/neo-series-gnss/zh-hans/neo-3-pro.html
- CUAV SKYE2: https://doc.cuav.net/others/skye/zh-hans/skye2.html
- 项目规则: `.trae/rules/airship*.md`
- 浮力硬件决策: `test/airship_test/BALLAST_HW_INTERFACE_DECISION.md`
