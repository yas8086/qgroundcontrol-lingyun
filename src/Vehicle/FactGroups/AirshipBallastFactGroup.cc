#include "AirshipBallastFactGroup.h"
#include "Vehicle.h"

AirshipBallastFactGroup::AirshipBallastFactGroup(QObject *parent)
    : FactGroup(200, QStringLiteral(":/json/Vehicle/AirshipBallastFact.json"), parent)
{
    _addFact(&_netBuoyancyFact);
    _addFact(&_blowerLeftFact);
    _addFact(&_blowerRightFact);
    _addFact(&_valveLeftFact);
    _addFact(&_valveRightFact);
    _addFact(&_altitudeErrorFact);

    // 初始值
    _netBuoyancyFact.setRawValue(0.0);
    _blowerLeftFact.setRawValue(0.0);
    _blowerRightFact.setRawValue(0.0);
    _valveLeftFact.setRawValue(0.0);
    _valveRightFact.setRawValue(0.0);
    _altitudeErrorFact.setRawValue(0.0);
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

    if (nameStr == QStringLiteral("buoy")) {
        _netBuoyancyFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blw_l")) {
        _blowerLeftFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blw_r")) {
        _blowerRightFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("vlv_l")) {
        _valveLeftFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("vlv_r")) {
        _valveRightFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("alt_err")) {
        _altitudeErrorFact.setRawValue(namedValue.value);
    } else {
        return;
    }

    _setTelemetryAvailable(true);
}
