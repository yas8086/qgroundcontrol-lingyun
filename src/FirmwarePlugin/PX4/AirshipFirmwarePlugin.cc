#include "AirshipFirmwarePlugin.h"
#include "Vehicle.h"

// 飞艇飞行模式 custom_mode 值（与标准 PX4 的位域编码不同，使用简单的 0-8）
// 注意：v2.0文档变更，Failsafe=7, Task=8（旧文档 Task=7 已作废）
namespace AirshipCustomMode {
    constexpr uint32_t MANUAL    = 0;
    constexpr uint32_t STABLE    = 1;
    constexpr uint32_t ALTITUDE  = 2;
    constexpr uint32_t POSITION  = 3;
    constexpr uint32_t OFFBOARD  = 4;
    constexpr uint32_t TAKEOFF   = 5;
    constexpr uint32_t LAND      = 6;
    constexpr uint32_t FAILSAFE  = 7;
    constexpr uint32_t TASK      = 8;
}

AirshipFirmwarePlugin::AirshipFirmwarePlugin()
{
    const QString manualFlightModeName     = tr("Manual");
    const QString stabilizedFlightModeName = tr("Stabilized");
    const QString altCtlFlightModeName     = tr("Altitude");
    const QString posCtlFlightModeName     = tr("Position");
    const QString offboardFlightModeName  = tr("Offboard");
    const QString takeoffFlightModeName    = tr("Takeoff");
    const QString landFlightModeName       = tr("Land");
    const QString failsafeFlightModeName   = tr("Failsafe");
    const QString missionFlightModeName    = tr("Mission");

    // 飞艇使用简化的 custom_mode 值（0-8），覆盖父类的标准 PX4 映射
    _setModeEnumToModeStringMapping({
        { AirshipCustomMode::MANUAL,    manualFlightModeName     },
        { AirshipCustomMode::STABLE,    stabilizedFlightModeName },
        { AirshipCustomMode::ALTITUDE,  altCtlFlightModeName     },
        { AirshipCustomMode::POSITION,  posCtlFlightModeName     },
        { AirshipCustomMode::OFFBOARD,  offboardFlightModeName  },
        { AirshipCustomMode::TAKEOFF,   takeoffFlightModeName    },
        { AirshipCustomMode::LAND,      landFlightModeName       },
        { AirshipCustomMode::FAILSAFE,  failsafeFlightModeName   },
        { AirshipCustomMode::TASK,      missionFlightModeName    },
    });

    // 飞艇可设置的飞行模式列表（Failsafe 不可手动设置，由系统自动触发）
    static FlightModeList availableFlightModes = {
        // Mode Name                  Custom Mode                       CanBeSet  adv
        { manualFlightModeName,      AirshipCustomMode::MANUAL,        true,   false },
        { stabilizedFlightModeName,  AirshipCustomMode::STABLE,        true,   false },
        { altCtlFlightModeName,      AirshipCustomMode::ALTITUDE,      true,   false },
        { posCtlFlightModeName,      AirshipCustomMode::POSITION,      true,   false },
        { offboardFlightModeName,    AirshipCustomMode::OFFBOARD,      true,   false },
        { takeoffFlightModeName,     AirshipCustomMode::TAKEOFF,       false,  false },
        { landFlightModeName,        AirshipCustomMode::LAND,          false,  false },
        { failsafeFlightModeName,    AirshipCustomMode::FAILSAFE,      false,  false },
        { missionFlightModeName,     AirshipCustomMode::TASK,          true,   false },
    };

    updateAvailableFlightModes(availableFlightModes);
}

AirshipFirmwarePlugin::~AirshipFirmwarePlugin()
{
}

QStringList AirshipFirmwarePlugin::flightModes(Vehicle* vehicle) const
{
    Q_UNUSED(vehicle);

    QStringList flightModesList;
    for (auto &mode : _flightModeList) {
        if (mode.canBeSet) {
            flightModesList += mode.mode_name;
        }
    }

    return flightModesList;
}

QString AirshipFirmwarePlugin::flightMode(uint8_t base_mode, uint32_t custom_mode) const
{
    if (base_mode & MAV_MODE_FLAG_CUSTOM_MODE_ENABLED) {
        return _modeEnumToString.value(custom_mode, tr("Unknown %1:%2").arg(base_mode).arg(custom_mode));
    }

    return QStringLiteral("Unknown");
}

bool AirshipFirmwarePlugin::setFlightMode(const QString& flightMode, uint8_t* base_mode, uint32_t* custom_mode) const
{
    *base_mode = 0;
    *custom_mode = 0;

    bool found = false;

    for (auto &mode : _flightModeList) {
        if (flightMode.compare(mode.mode_name, Qt::CaseInsensitive) == 0) {
            *base_mode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
            *custom_mode = mode.custom_mode;
            found = true;
            break;
        }
    }

    return found;
}

QString AirshipFirmwarePlugin::pauseFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::POSITION);
}

QString AirshipFirmwarePlugin::missionFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::TASK);
}

QString AirshipFirmwarePlugin::landFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::LAND);
}

QString AirshipFirmwarePlugin::takeOffFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::TAKEOFF);
}

QString AirshipFirmwarePlugin::takeControlFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::MANUAL);
}

QString AirshipFirmwarePlugin::gotoFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::POSITION);
}

QString AirshipFirmwarePlugin::stabilizedFlightMode() const
{
    return _modeEnumToString.value(AirshipCustomMode::STABLE);
}

QString AirshipFirmwarePlugin::missionCommandOverrides(QGCMAVLink::VehicleClass_t vehicleClass) const
{
    if (vehicleClass == QGCMAVLink::VehicleClassAirship) {
        return QStringLiteral(":/json/PX4-MavCmdInfoAirship.json");
    }
    return PX4FirmwarePlugin::missionCommandOverrides(vehicleClass);
}

QVariant AirshipFirmwarePlugin::expandedToolbarIndicatorSource(const Vehicle* vehicle, const QString& indicatorName) const
{
    Q_UNUSED(vehicle);

    if (indicatorName == "FlightMode") {
        return QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/FirmwarePlugin/PX4/PX4AirshipFlightModeIndicator.qml"));
    }
    return PX4FirmwarePlugin::expandedToolbarIndicatorSource(vehicle, indicatorName);
}
