# 灵云01号飞艇 - QGC集成开发文档索引

**文档版本**: 3.2 (2026-08-30全量代码分析 + print_status越界修复 + 固件FLASH裁剪)
**最后更新**: 2026-08-30
**维护方式**: 仅PX4项目维护,QGC项目通过路径引用
**QGC项目引用方式**: 在QGC项目根目录创建 `docs/PX4_INTEGRATION_REFERENCE.md`,内容为指向本目录的绝对路径

---

## 文档结构

| 文件 | 主题 | 适用读者 |
|------|------|---------|
| [01_overview.md](01_overview.md) | 飞艇概述、物理特性、5DOF控制架构、电机布局 | QGC架构师、UI设计师 |
| [02_parameters.md](02_parameters.md) | 完整参数表(仿真值+实飞首飞值两套)、参数分组 | QGC参数界面开发 |
| [03_interfaces.md](03_interfaces.md) | uORB消息、MAVLink接口、Offboard控制协议 | QGC通信层开发 |
| [04_modes.md](04_modes.md) | 飞行模式枚举、状态机、前置条件、failsafe逻辑 | QGC模式显示、任务规划 |
| [05_hardware.md](05_hardware.md) | 实飞硬件接口(x25-evo板、传感器、PWM通道映射) | QGC硬件配置界面 |
| [06_qgc_dev_guide.md](06_qgc_dev_guide.md) | QGC开发要点(UI定制、HUD元素、参数页面建议) | QGC前端开发 |

---

## 关键变化(相对v2.0文档, 2026-08-30全量代码分析确认)

1. **V2十电机布局**: 4上升(四角)+2下降(中轴)+4推进(四角,可反转[-0.6,+0.6]), CA_ROTOR_COUNT=10, CA_R_REV=0x3FF (旧文档8电机已作废)
2. **四气囊构型**: 2主囊+2副囊, 四囊同步充放气; 浮力执行器=4囊×(风机+阀门)=8通道(PWM_AUX 201-208)
3. **横滚闭环(V2新增)**: AS_ROLL_*/AS_RR_*参数, 上升电机左右差动; TRIM_BALLOON_*已删除(气囊不参与横滚)
4. **PropTest=9(ACRO)**: 单侧推进测试模式, CA_AS_PT_EN/SIDE/THR
5. **物理常数全面更新(V2几何)**: K_LUP=K_LDN=222.5, K_PROP=1352.4, PZ_PROP=0.878, PX_FRONT/REAR=7.557/9.843, 新增CA_AS_PROP_MAX=0.6
6. **新消息**: airship_altitude_setpoint(控制器→ballast高度目标); ballast_setpoint扩展为float32[4]+uint8[4]×2四囊字段
7. **浮力系统QGC可见**: NAMED_VALUE_FLOAT 5字段轮转(buoy/alt_err/b_mass/blower/valve)
8. **RTL语义**: 飞艇RTL=Altitude原地悬停(不飞回home); Land完成自动强制DISARM; 起飞完成自动切LOITER
9. **Takeoff状态机**: Settle(5s)→Climb(限速0.5m/s+软启动)→Hold(20s±2m)→Complete; 高度门槛AS_TAKEOFF_ALT前置检查
10. **Commander事实**: 飞艇归旋翼(is_rotary_wing), AUTO_TAKEOFF已解锁时需完整local_position; NAV_LAND force=true总是可切入
11. **PWM映射**: 电机走MAIN 1-10(Func101-110), ballast 8通道走AUX 1-8(Func201-208, DIS=1000); x25-evo真机PWM_AUX静默失效待迁移
12. **新参数**: AS_TKF_VMAX/AS_ROLL_*/AS_RR_*/CA_AS_PROP_MAX/CA_AS_PT_*/BALLOON_M_MAX/BLWR_FLOW/BALLOON_MIN_ON/BALLOON_SWT_GD/BALLOON_EMG_EN/VALVE_FLOW_MAX/BALLOON_OUT_EN; BALLOON_THRSHLD为死参数
13. **已知问题清单**: Takeoff手动油门velocity(2)不生效、failsafe不发STATUSTEXT(QGC无告警)、CA_AS_K_LDN声明未用、下降组力臂硬编码、SDF推进旋向与规则文档不一致(以SDF为准)
14. **摇杆映射确认**: Throttle→前进推力, Pitch杆→俯仰角(Manual兼升降速度), Roll杆→偏航速率, Yaw杆→俯仰(Stable/Altitude); 与rc.lingyun01_defaults注释和FlightTask代码一致
15. **print_status越界修复(2026-08-30)**: PropTest=9时`airship_att_control status`越界读数组。修复: 两处mode_names提取为文件级共享常量kModeNames(AirshipControl.cpp L6-10) + static_assert绑定AirshipMode枚举长度, 未来新增枚举值漏更数组将编译失败
16. **固件FLASH裁剪(2026-08-30)**: 95.08%→87.34%(-148.5KB), 明细见`docs/lingyun/flash_trim_record.md`。QGC侧影响: ①**无测距仪驱动**(land_detector物理触地检测不可用, landed纯运动学判定) ②罗盘仅RM3100+IST8310+DroneCAN ③空速仅ms4525do ④DShot固件级移除(仅PWM/DroneCAN输出)

---

## AI辅助开发使用指南

**QGC项目AI在Trae中查询PX4开发细节时,应遵循以下流程**:

1. **先读本索引**: 了解有哪些主题文档
2. **按需读取主题文件**: 不要一次性读完所有文件,根据任务需要读取对应主题
3. **参数查询**: 优先读 `02_parameters.md`,它包含所有参数的完整定义
4. **接口对接**: 通信层任务读 `03_interfaces.md`,包含uORB和MAVLink完整接口
5. **模式显示**: UI任务读 `04_modes.md`,包含模式枚举和状态机
6. **硬件配置**: 配置界面任务读 `05_hardware.md`,包含PWM通道映射
7. **跨主题查询**: 如果一个任务涉及多个主题,先读索引定位,再读多个主题文件

---

## 文档维护规则

1. **单一数据源**: PX4代码变更后,必须同步更新对应主题文件
2. **不重复**: 同一信息只在一个文件中详述,其他文件仅引用
3. **结构化优先**: 参数表、消息字段表、模式映射表使用Markdown表格
4. **场景标注**: 实飞和仿真差异处必须明确标注 `[实飞]` 或 `[仿真]`
5. **版本对应**: 每次更新文档版本号+1,并更新"最后更新"日期
