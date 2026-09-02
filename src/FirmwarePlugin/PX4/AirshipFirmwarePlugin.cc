#include "AirshipFirmwarePlugin.h"
#include "Vehicle.h"

// PX4 端 custom_mode 由 get_px4_custom_mode(nav_state) 纯标准 PX4 位域生成
// (main_mode << 16 | sub_mode << 24)，无飞艇特殊分支（03_interfaces.md §4）。
// AirshipMode 内部枚举不出现在任何 MAVLink 消息中，QGC 必须按标准编码解析。
//
// 飞艇模式语义（04_modes.md / 06_qgc_dev_guide.md §1.2）：
//   Manual/Stabilized/Altitude/Position/Offboard 一一对应标准模式；
//   Takeoff = AUTO sub2, Land = AUTO sub6, Task = AUTO_MISSION；
//   Failsafe 为 airship_att_control 内部态，不反映到 nav_state（QGC 收不到）；
//   PropTest = ACRO（需 CA_AS_PT_EN=1，单侧推进测试）；
//   Loiter/RTL 对飞艇均为 Altitude 原地悬停（RTL 不飞回 home）。
AirshipFirmwarePlugin::AirshipFirmwarePlugin()
{
    const QString manualFlightModeName     = tr("Manual");
    const QString stabilizedFlightModeName = tr("Stabilized");
    const QString acroFlightModeName       = tr("Acro");
    const QString altCtlFlightModeName     = tr("Altitude");
    const QString posCtlFlightModeName     = tr("Position");
    const QString offboardFlightModeName   = tr("Offboard");
    const QString takeoffFlightModeName    = tr("Takeoff");
    const QString landFlightModeName       = tr("Land");
    const QString loiterFlightModeName     = tr("Loiter");
    const QString missionFlightModeName    = tr("Mission");
    const QString rtlFlightModeName        = tr("RTL");

    _setModeEnumToModeStringMapping({
        { PX4CustomMode::MANUAL,        manualFlightModeName     },
        { PX4CustomMode::STABILIZED,    stabilizedFlightModeName },
        { PX4CustomMode::ACRO,          acroFlightModeName       },
        { PX4CustomMode::ALTCTL,        altCtlFlightModeName     },
        { PX4CustomMode::POSCTL_POSCTL, posCtlFlightModeName     },
        { PX4CustomMode::OFFBOARD,      offboardFlightModeName   },
        { PX4CustomMode::AUTO_TAKEOFF,  takeoffFlightModeName    },
        { PX4CustomMode::AUTO_LAND,     landFlightModeName       },
        { PX4CustomMode::AUTO_LOITER,   loiterFlightModeName     },
        { PX4CustomMode::AUTO_MISSION,  missionFlightModeName    },
        { PX4CustomMode::AUTO_RTL,      rtlFlightModeName        },
    });

    // 飞艇可设置模式列表（06_qgc_dev_guide.md §1.2 启用条件）：
    //   Takeoff/Land 不可由模式列表切换（Takeoff 需 ARMED+完整 local_position，
    //   Land 通过 MAV_CMD_NAV_LAND 命令触发且 force=true 总是可切入）。
    //   RTL 保留可切换：飞艇 RTL = 原地定高悬停（链路恢复后的安全驻留）。
    static FlightModeList availableFlightModes = {
        // Mode Name                Custom Mode                       CanBeSet  adv
        { manualFlightModeName,     PX4CustomMode::MANUAL,            true,   false },
        { stabilizedFlightModeName, PX4CustomMode::STABILIZED,        true,   false },
        { acroFlightModeName,       PX4CustomMode::ACRO,              true,   true  },
        { altCtlFlightModeName,     PX4CustomMode::ALTCTL,            true,   false },
        { posCtlFlightModeName,     PX4CustomMode::POSCTL_POSCTL,     true,   false },
        { offboardFlightModeName,   PX4CustomMode::OFFBOARD,          true,   true  },
        { takeoffFlightModeName,    PX4CustomMode::AUTO_TAKEOFF,      false,  false },
        { landFlightModeName,       PX4CustomMode::AUTO_LAND,         false,  false },
        { loiterFlightModeName,     PX4CustomMode::AUTO_LOITER,       true,   true  },
        { missionFlightModeName,    PX4CustomMode::AUTO_MISSION,      true,   true  },
        { rtlFlightModeName,        PX4CustomMode::AUTO_RTL,          true,   true  },
    };

    updateAvailableFlightModes(availableFlightModes);
}

AirshipFirmwarePlugin::~AirshipFirmwarePlugin()
{
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
