# 灵云01号飞艇 - QGC集成开发指南(入口)

> **注意**: 本文件为入口指引。完整文档已迁移到 `docs/qgc_integration/` 目录,按主题拆分。
>
> **QGC项目AI请优先读取**: `/home/hex/PX4-Autopilot/docs/qgc_integration/00_INDEX.md`

---

## 文档结构(按主题拆分)

| 文件 | 主题 | 适用场景 |
|------|------|---------|
| [docs/qgc_integration/00_INDEX.md](docs/qgc_integration/00_INDEX.md) | 索引与导航 | 入口,先读此文件 |
| [docs/qgc_integration/01_overview.md](docs/qgc_integration/01_overview.md) | 飞艇概述、物理特性、4DOF控制架构、电机布局 | 架构师、UI设计师 |
| [docs/qgc_integration/02_parameters.md](docs/qgc_integration/02_parameters.md) | 完整参数表(仿真值+实飞首飞值两套) | QGC参数界面开发 |
| [docs/qgc_integration/03_interfaces.md](docs/qgc_integration/03_interfaces.md) | uORB消息、MAVLink接口、Offboard控制协议 | QGC通信层开发 |
| [docs/qgc_integration/04_modes.md](docs/qgc_integration/04_modes.md) | 飞行模式枚举、状态机、前置条件、failsafe | QGC模式显示、任务规划 |
| [docs/qgc_integration/05_hardware.md](docs/qgc_integration/05_hardware.md) | 实飞硬件接口(x25-evo板、传感器、PWM通道映射) | QGC硬件配置界面 |
| [docs/qgc_integration/06_qgc_dev_guide.md](docs/qgc_integration/06_qgc_dev_guide.md) | QGC开发要点(UI定制、HUD元素、参数页面建议) | QGC前端开发 |

---

## 关键变更(相对v1.0文档)

1. **机型文件**: 仿真专用 `2058_gz_lingyun01` 已合并为 `2058_lingyun01` (仿真+实飞合一)
2. **模式枚举**: `Failsafe=7, Task=8` (旧文档 `Task=7` 已作废)
3. **新方案无舵机**: `CA_SV_CS_COUNT=0`, 升力电机AZ控制推力方向
4. **新增ballast_output模块**: 独立桥接 `ballast_setpoint → actuator_servos → PWM_AUX`
5. **新增分阶段降落速度**: `AS_LND_VHI/VMID/VLO/VGND`
6. **新增高度硬/软限位**: `AS_ALT_MAX/MIN/SOFT`
7. **新增自动测试/调参**: `AS_TST_*` (阶跃测试)、`AS_AT_*` (PID自整定)
8. **实飞首飞PID保守值**: 在 `2058_lingyun01` 中PID增益减半
9. **Offboard接口明确**: `body_roll_rate→thrust_x`, `body_pitch_rate→thrust_y`, `thrust→thrust_z`
10. **完整实飞硬件接口**: CAN GPS / I2C空速 / 以太网CC / TELEM1数传57600bps

---

## QGC项目集成方式

**在QGC项目根目录创建 `docs/PX4_INTEGRATION_REFERENCE.md`**, 内容如下:

```markdown
# PX4飞艇开发细节参考

PX4飞艇开发细节由PX4项目维护,QGC项目通过路径引用。

**入口文件**: /home/hex/PX4-Autopilot/docs/qgc_integration/00_INDEX.md

**使用方式**:
1. QGC AI 在Trae中查询PX4开发细节时,先读入口文件
2. 根据任务需要读取对应主题文件(不要一次性读完)
3. 参数查询: 02_parameters.md
4. 接口对接: 03_interfaces.md
5. 模式显示: 04_modes.md
6. 硬件配置: 05_hardware.md
7. UI定制: 06_qgc_dev_guide.md

**维护规则**: PX4代码变更后,同步更新 docs/qgc_integration/ 对应文件,QGC项目无需手动同步。
```

---

## 文档版本

- **版本**: 2.0
- **最后更新**: 2026-07-07
- **适用PX4版本**: 定制版(基于v1.14+)
- **适用QGC版本**: v4.0+
- **状态**: 进入实机开发阶段,已生成x25-evo实飞固件
