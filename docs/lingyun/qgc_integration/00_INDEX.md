# 灵云01号飞艇 - QGC集成开发文档索引

**文档版本**: 2.2
**最后更新**: 2026-07-15
**维护方式**: 仅PX4项目维护,QGC项目通过路径引用
**QGC项目引用方式**: 在QGC项目根目录创建 `docs/PX4_INTEGRATION_REFERENCE.md`,内容为指向本目录的绝对路径

---

## 文档结构

| 文件 | 主题 | 适用读者 |
|------|------|---------|
| [01_overview.md](01_overview.md) | 飞艇概述、物理特性、4DOF控制架构、电机布局 | QGC架构师、UI设计师 |
| [02_parameters.md](02_parameters.md) | 完整参数表(仿真值+实飞首飞值两套)、参数分组 | QGC参数界面开发 |
| [03_interfaces.md](03_interfaces.md) | uORB消息、MAVLink接口、Offboard控制协议 | QGC通信层开发 |
| [04_modes.md](04_modes.md) | 飞行模式枚举、状态机、前置条件、failsafe逻辑 | QGC模式显示、任务规划 |
| [05_hardware.md](05_hardware.md) | 实飞硬件接口(x25-evo板、传感器、PWM通道映射) | QGC硬件配置界面 |
| [06_qgc_dev_guide.md](06_qgc_dev_guide.md) | QGC开发要点(UI定制、HUD元素、参数页面建议) | QGC前端开发 |

---

## 关键变化(相对v1.0文档)

1. **机型文件分裂**: 仿真专用 `2058_gz_lingyun01` 已合并为 `2058_lingyun01` (同时支持仿真和实飞)
2. **模式枚举变更**: `Failsafe=7, Task=8` (旧文档 `Task=7` 已作废)
3. **新增无舵机方案**: `CA_SV_CS_COUNT=0`, 升力电机AZ控制推力方向
4. **新增ballast_output模块**: 独立桥接 `ballast_setpoint → actuator_servos → PWM_AUX`
5. **新增分阶段降落速度**: `AS_LND_VHI/VMID/VLO/VGND`
6. **新增高度硬/软限位**: `AS_ALT_MAX/MIN/SOFT`
7. **新增自动测试/调参**: `AS_TST_*` (阶跃测试)、`AS_AT_*` (PID自整定)
8. **实飞首飞PID保守值**: 在 `2058_lingyun01` 中PID增益减半
9. **Offboard接口明确**: `body_roll_rate→thrust_x`, `body_pitch_rate→thrust_y`, `thrust→thrust_z`
10. **完整实飞硬件接口**: CAN GPS / I2C空速 / 以太网CC / TELEM1数传57600bps
11. **新增横滚主动控制**: ballast_control 独立级联PID（四气囊浮力差，角度外环P+I → 角速度内环P+D），att_control 的 torque_x 置0（横滚不通过电机控制），ballast_setpoint 新增 roll_moment_demand/ballast_mass[4]/ballast_blower_in[4] 等字段
12. **横滚控制已验证**: 仿真9项检查全部通过，稳态横滚角 < 1deg，参数优化完成（BALLOON_R_P=2.0, BALLOON_RR_P=1.0, BLWR_FLOW=0.5仿真加速）
13. **摇杆映射修正**: Throttle→高度, Pitch杆→前进推力, Roll杆→偏航, Yaw杆→俯仰（原文档Throttle和Pitch杆映射错误已修正）

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
