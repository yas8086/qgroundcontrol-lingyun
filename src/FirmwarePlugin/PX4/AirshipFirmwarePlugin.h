#pragma once

#include "PX4FirmwarePlugin.h"

/**
 * @brief 飞艇专用固件插件
 *
 * 灵云01号飞艇使用简化的 custom_mode 值（0-7），与标准 PX4 的位域编码不同。
 * 此插件重写飞行模式映射，使 QGC 能正确识别和切换飞艇的 8 种飞行模式。
 *
 * 飞艇飞行模式映射：
 *   0 - Manual    手动模式
 *   1 - Stable    自稳定模式
 *   2 - Altitude  定高模式
 *   3 - Position   定点模式
 *   4 - Offboard   外部控制模式
 *   5 - Takeoff    起飞模式
 *   6 - Land       降落模式
 *   7 - Task       任务模式
 */
class AirshipFirmwarePlugin : public PX4FirmwarePlugin
{
    Q_OBJECT

public:
    AirshipFirmwarePlugin();
    ~AirshipFirmwarePlugin();

    // 飞行模式映射
    QStringList flightModes(Vehicle* vehicle) const override;
    QString flightMode(uint8_t base_mode, uint32_t custom_mode) const override;
    bool setFlightMode(const QString& flightMode, uint8_t* base_mode, uint32_t* custom_mode) const override;

    // 任务命令覆盖 - 飞艇专用任务规划
    QString missionCommandOverrides(QGCMAVLink::VehicleClass_t vehicleClass) const override;

    // 工具栏扩展指示器 - 飞艇专用状态显示
    QVariant expandedToolbarIndicatorSource(const Vehicle* vehicle, const QString& indicatorName) const override;

    // 飞行模式名称
    QString pauseFlightMode() const override;
    QString missionFlightMode() const override;
    QString landFlightMode() const override;
    QString takeOffFlightMode() const override;
    QString takeControlFlightMode() const override;
    QString gotoFlightMode() const override;
    QString stabilizedFlightMode() const override;
};
