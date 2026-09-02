#pragma once

#include "PX4FirmwarePlugin.h"

/**
 * @brief 飞艇专用固件插件
 *
 * 灵云01号飞艇的 custom_mode 由 PX4 get_px4_custom_mode() 纯标准位域生成
 * (main_mode << 16 | sub_mode << 24)，与标准 PX4 一致（03_interfaces.md §4）。
 * 本插件仅注入飞艇模式的名称映射与可设置模式列表：
 *   Manual / Stabilized / Acro(PropTest) / Altitude / Position / Offboard /
 *   Takeoff(AUTO sub2) / Land(AUTO sub6) / Loiter / Mission / RTL
 * 其余行为（模式解析、切换、pause/land/rtl 等虚函数）复用父类实现，
 * 通过 _modeEnumToString 查表自动生效。
 *
 * 飞艇语义差异（04_modes.md）：
 *   - RTL = 原地定高悬停（不飞回 home）
 *   - Loiter = Altitude 悬停
 *   - Failsafe 为飞控内部态，不反映到 nav_state（QGC 不可见）
 *   - 起飞完成自动切 Loiter、Land 到 3m 自动 DISARM 属正常行为
 */
class AirshipFirmwarePlugin : public PX4FirmwarePlugin
{
    Q_OBJECT

public:
    AirshipFirmwarePlugin();
    ~AirshipFirmwarePlugin();

    // 任务命令覆盖 - 飞艇专用任务规划
    QString missionCommandOverrides(QGCMAVLink::VehicleClass_t vehicleClass) const override;

    // 工具栏扩展指示器 - 飞艇专用状态显示
    QVariant expandedToolbarIndicatorSource(const Vehicle* vehicle, const QString& indicatorName) const override;
};
