#pragma once

#include "FactGroup.h"

/**
 * @brief 飞艇浮力控制状态 FactGroup
 *
 * PX4 ballast_control 通过 NAMED_VALUE_FLOAT 轮转发布 5 个字段（每字段约 10Hz，
 * 03_interfaces.md §5）。V2 四囊同步构型（2主囊+2副囊同步充放气），
 * 四囊同一值，无左右之分：
 *   "buoy"    → netBuoyancy   (净浮力调整量 N，正=上升)
 *   "alt_err" → altitudeError (高度误差 m)
 *   "b_mass"  → ballastMass   (单囊空气质量 kg，0 ~ BALLOON_M_MAX=128.5)
 *   "blower"  → blowerDuty    (风机占空比 0-255，0=停)
 *   "valve"   → valveState    (阀门状态 0=关 / 255=开，常闭阀)
 */
class AirshipBallastFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *netBuoyancy   READ netBuoyancy   CONSTANT)
    Q_PROPERTY(Fact *altitudeError READ altitudeError CONSTANT)
    Q_PROPERTY(Fact *ballastMass   READ ballastMass   CONSTANT)
    Q_PROPERTY(Fact *blowerDuty    READ blowerDuty    CONSTANT)
    Q_PROPERTY(Fact *valveState    READ valveState    CONSTANT)

public:
    explicit AirshipBallastFactGroup(QObject *parent = nullptr);

    Fact *netBuoyancy()   { return &_netBuoyancyFact; }
    Fact *altitudeError() { return &_altitudeErrorFact; }
    Fact *ballastMass()   { return &_ballastMassFact; }
    Fact *blowerDuty()    { return &_blowerDutyFact; }
    Fact *valveState()    { return &_valveStateFact; }

    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) override;

private:
    Fact _netBuoyancyFact    {0, QStringLiteral("netBuoyancy"),   FactMetaData::valueTypeDouble};
    Fact _altitudeErrorFact  {0, QStringLiteral("altitudeError"), FactMetaData::valueTypeDouble};
    Fact _ballastMassFact    {0, QStringLiteral("ballastMass"),   FactMetaData::valueTypeDouble};
    Fact _blowerDutyFact     {0, QStringLiteral("blowerDuty"),    FactMetaData::valueTypeDouble};
    Fact _valveStateFact     {0, QStringLiteral("valveState"),    FactMetaData::valueTypeDouble};
};
