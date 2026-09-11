#include "AirshipBallastFactGroup.h"
#include "Vehicle.h"

AirshipBallastFactGroup::AirshipBallastFactGroup(QObject *parent)
    : FactGroup(200, QStringLiteral(":/json/Vehicle/AirshipBallastFact.json"), parent)
{
    _addFact(&_netBuoyancyFact);
    _addFact(&_altitudeErrorFact);
    _addFact(&_ballastMassFact);
    _addFact(&_blower0Fact);
    _addFact(&_blower1Fact);
    _addFact(&_blower2Fact);
    _addFact(&_blower3Fact);
    _addFact(&_valve0Fact);
    _addFact(&_valve1Fact);
    _addFact(&_valve2Fact);
    _addFact(&_valve3Fact);
    _addFact(&_bladderPressure0Fact);
    _addFact(&_bladderPressure1Fact);
    _addFact(&_bladderPressure2Fact);
    _addFact(&_bladderPressure3Fact);

    // 初始值
    _netBuoyancyFact.setRawValue(0.0);
    _altitudeErrorFact.setRawValue(0.0);
    _ballastMassFact.setRawValue(0.0);
    // 四路风机/阀门与四囊压差初始值 NaN：未收到数据时 UI 显示 "—" 而非误导性的 0
    for (Fact *fact : {&_blower0Fact, &_blower1Fact, &_blower2Fact, &_blower3Fact,
                       &_valve0Fact, &_valve1Fact, &_valve2Fact, &_valve3Fact,
                       &_bladderPressure0Fact, &_bladderPressure1Fact, &_bladderPressure2Fact, &_bladderPressure3Fact}) {
        fact->setRawValue(qQNaN());
    }
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

    // PX4 ballast_control 十三字段轮转（03_interfaces.md §5 + 四囊压差/风机/阀门透出），
    // 每囊独立执行器：blower0~3 占空比 0-100，valve0~3 开关 0/100，bal_p0~3 表压 kPa。
    if (nameStr == QStringLiteral("buoy")) {
        _netBuoyancyFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("alt_err")) {
        _altitudeErrorFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("b_mass")) {
        _ballastMassFact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blower0")) {
        _blower0Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blower1")) {
        _blower1Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blower2")) {
        _blower2Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("blower3")) {
        _blower3Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("valve0")) {
        _valve0Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("valve1")) {
        _valve1Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("valve2")) {
        _valve2Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("valve3")) {
        _valve3Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("bal_p0")) {
        _bladderPressure0Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("bal_p1")) {
        _bladderPressure1Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("bal_p2")) {
        _bladderPressure2Fact.setRawValue(namedValue.value);
    } else if (nameStr == QStringLiteral("bal_p3")) {
        _bladderPressure3Fact.setRawValue(namedValue.value);
    } else {
        return;
    }

    _setTelemetryAvailable(true);
}
