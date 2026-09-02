#include "SensorsComponent.h"
#include "ParameterManager.h"
#include "Vehicle.h"

SensorsComponent::SensorsComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, AutoPilotPlugin::KnownSensorsVehicleComponent, parent)
    , _name(tr("Sensors"))
{
    _deviceIds = QStringList({QStringLiteral("CAL_GYRO0_ID"), QStringLiteral("CAL_ACC0_ID") });

    if (_vehicle->fixedWing() || _vehicle->vtol() || _vehicle->airship()) {
        _airspeedCalTriggerParams << "SENS_DPRES_OFF";
        // Custom PX4 forks can report arbitrary version numbers (Lingyun01 airship
        // reports 1.6.2dev while carrying modern 1.14+ params), so treat airship
        // explicitly as modern. Verified on Lingyun01 firmware: SYS_HAS_NUM_ASPD
        // exists, FW_ARSP_MODE/CBRK_AIRSPD_CHK do not.
        if (_vehicle->airship() || (_vehicle->firmwareMajorVersion() >= 1 && _vehicle->firmwareMinorVersion() >= 14)) {
            _airspeedCalTriggerParams << "SYS_HAS_NUM_ASPD";
        } else {
            _airspeedCalTriggerParams << "FW_ARSP_MODE" << "CBRK_AIRSPD_CHK";
        }
    }
}

QString SensorsComponent::name(void) const
{
    return _name;
}

QString SensorsComponent::description(void) const
{
    return tr("Configure and calibrate gyroscope, accelerometer, magnetometer, and airspeed sensors.");
}

QString SensorsComponent::iconResource(void) const
{
    return "/qmlimages/SensorsComponentIcon.png";
}

bool SensorsComponent::requiresSetup(void) const
{
    return true;
}

bool SensorsComponent::setupComplete(void) const
{
    for (const QString &triggerParam : std::as_const(_deviceIds)) {
        if (_vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, triggerParam)->rawValue().toFloat() == 0.0f) {
            return false;
        }
    }
    bool magEnabled = true;
    if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, _magEnabledParam)) {
        magEnabled = _vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, _magEnabledParam)->rawValue().toBool();
    }

    if (magEnabled && _vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, _magCalParam)->rawValue().toFloat() == 0.0f) {
        return false;
    }

    if (_vehicle->fixedWing() || _vehicle->vtol() || _vehicle->airship()) {
        // Decide by parameter existence instead of firmware version: custom forks can
        // report arbitrary version numbers (see constructor comment).
        auto *pm = _vehicle->parameterManager();
        if (pm->parameterExists(ParameterManager::defaultComponentId, "SYS_HAS_NUM_ASPD")) {
            if (pm->getParameter(ParameterManager::defaultComponentId, "SYS_HAS_NUM_ASPD")->rawValue().toBool() &&
                    pm->getParameter(ParameterManager::defaultComponentId, "SENS_DPRES_OFF")->rawValue().toFloat() == 0.0f) {
                return false;
            }
        } else if (pm->parameterExists(ParameterManager::defaultComponentId, "FW_ARSP_MODE")) {
            if (!pm->getParameter(ParameterManager::defaultComponentId, "FW_ARSP_MODE")->rawValue().toBool() &&
                    pm->getParameter(ParameterManager::defaultComponentId, "CBRK_AIRSPD_CHK")->rawValue().toInt() != 162128 &&
                    pm->getParameter(ParameterManager::defaultComponentId, "SENS_DPRES_OFF")->rawValue().toFloat() == 0.0f) {
                return false;
            }
        }
        // else: firmware has no airspeed params at all — nothing to check
    }

    return true;
}

QStringList SensorsComponent::setupCompleteChangedTriggerList(void) const
{
    QStringList triggers;

    triggers << _deviceIds << _magCalParam << _magEnabledParam;
    if (_vehicle->fixedWing() || _vehicle->vtol() || _vehicle->airship()) {
        triggers << _airspeedCalTriggerParams;
    }

    return triggers;
}

QUrl SensorsComponent::setupSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/SensorsComponent.qml");
}

QStringList SensorsComponent::sections() const
{
    QStringList sectionList;

    // Compass (hidden when all mags disabled)
    bool allMagsDisabled = false;
    if (_vehicle->parameterManager()->parameterExists(ParameterManager::defaultComponentId, _magEnabledParam)) {
        allMagsDisabled = !_vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, _magEnabledParam)->rawValue().toBool();
    }
    if (!allMagsDisabled) {
        sectionList << tr("Compass");
    }

    sectionList << tr("Gyroscope");
    sectionList << tr("Accelerometer");
    sectionList << tr("Level Horizon");

    if (_airspeedCalSupported()) {
        sectionList << tr("Airspeed");
    }

    sectionList << tr("Orientations");

    return sectionList;
}

QUrl SensorsComponent::summaryQmlSource(void) const
{
    QString summaryQml;

    if (_vehicle->fixedWing() || _vehicle->vtol() || _vehicle->airship()) {
        summaryQml = "qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/SensorsComponentSummaryFixedWing.qml";
    } else {
        summaryQml = "qrc:/qml/QGroundControl/AutoPilotPlugins/PX4/SensorsComponentSummary.qml";
    }

    return QUrl::fromUserInput(summaryQml);
}

 bool SensorsComponent::_airspeedCalSupported(void) const
 {
    if (_vehicle->fixedWing() || _vehicle->vtol() || _vehicle->airship()) {
        // Decide by parameter existence instead of firmware version (see constructor comment).
        auto *pm = _vehicle->parameterManager();
        if (pm->parameterExists(ParameterManager::defaultComponentId, "SYS_HAS_NUM_ASPD")) {
            return pm->getParameter(ParameterManager::defaultComponentId, "SYS_HAS_NUM_ASPD")->rawValue().toBool();
        }
        if (pm->parameterExists(ParameterManager::defaultComponentId, "FW_ARSP_MODE")) {
            return !pm->getParameter(ParameterManager::defaultComponentId, "FW_ARSP_MODE")->rawValue().toBool() &&
                    pm->getParameter(ParameterManager::defaultComponentId, "CBRK_AIRSPD_CHK")->rawValue().toInt() != 162128;
        }
    }

    return false;
 }

 bool SensorsComponent::_airspeedCalRequired(void) const
 {
    return _airspeedCalSupported() && _vehicle->parameterManager()->getParameter(ParameterManager::defaultComponentId, "SENS_DPRES_OFF")->rawValue().toFloat() == 0.0f;
 }

bool SensorsComponent::sectionSetupComplete(const QString &sectionName) const
{
    auto *pm = _vehicle->parameterManager();

    if (sectionName == tr("Compass")) {
        bool magEnabled = true;
        if (pm->parameterExists(ParameterManager::defaultComponentId, _magEnabledParam)) {
            magEnabled = pm->getParameter(ParameterManager::defaultComponentId, _magEnabledParam)->rawValue().toBool();
        }
        if (!magEnabled) return true;
        return pm->getParameter(ParameterManager::defaultComponentId, _magCalParam)->rawValue().toFloat() != 0.0f;
    }
    if (sectionName == tr("Gyroscope")) {
        return pm->getParameter(ParameterManager::defaultComponentId, "CAL_GYRO0_ID")->rawValue().toFloat() != 0.0f;
    }
    if (sectionName == tr("Accelerometer")) {
        return pm->getParameter(ParameterManager::defaultComponentId, "CAL_ACC0_ID")->rawValue().toFloat() != 0.0f;
    }
    if (sectionName == tr("Level Horizon")) {
        // Level cal doesn't have a distinct completion indicator — consider complete if accel+gyro are done
        return pm->getParameter(ParameterManager::defaultComponentId, "CAL_ACC0_ID")->rawValue().toFloat() != 0.0f
            && pm->getParameter(ParameterManager::defaultComponentId, "CAL_GYRO0_ID")->rawValue().toFloat() != 0.0f;
    }
    if (sectionName == tr("Airspeed")) {
        return !_airspeedCalRequired();
    }

    return true;
}
