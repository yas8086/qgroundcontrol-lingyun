#include "AirshipBallastFactGroup.h"
#include "Vehicle.h"

AirshipBallastFactGroup::AirshipBallastFactGroup(QObject *parent)
    : FactGroup(200, QStringLiteral(":/json/Vehicle/AirshipBallastFact.json"), parent)
{
    _addFact(&_netBuoyancyFact);
    _addFact(&_altitudeErrorFact);
    _addFact(&_ballastMassFact);
    _addFact(&_blowerDutyFact);
    _addFact(&_valveStateFact);

    // 初始值
    _netBuoyancyFact.setRawValue(0.0);
    _altitudeErrorFact.setRawValue(0.0);
    _ballastMassFact.setRawValue(0.0);
    _blowerDutyFact.setRawValue(0.0);
    _valveStateFact.setRawValue(0.0);
}

void AirshipBallastFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_NAMED_VALUE_FLOAT) {
        return;
    }

    mavlink_named_value_float_t namedValue;
    mavlink_msg_named_value_float_decode(&message, &namedValue);

    // 确保 name 以 null 结尾
    char name[MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN + 1];
    memcpy(name, namedValue.name, MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN);
    name[MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN] = '\0';
    const QString nameStr = QString::fromLatin1(name).trimmed();

    // PX4 ballast_control 五字段轮转（03_interfaces.md §5），
    // 四囊同步构型无左右之分。
    if (nameStr == QStringLiteral("buoy")) {
        _netBuoyancyFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("alt_err")) {
        _altitudeErrorFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("b_mass")) {
        _ballastMassFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blower")) {
        _blowerDutyFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("valve")) {
        _valveStateFact.setRawValue(namedValue.value);
    } else {
        return;
    }

    _setTelemetryAvailable(true);
}
