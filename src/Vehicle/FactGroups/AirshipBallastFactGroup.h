#pragma once

#include "FactGroup.h"

/**
 * @brief 飞艇浮力控制状态 FactGroup
 *
 * PX4 ballast_control 通过 NAMED_VALUE_FLOAT 轮转发布 15 个字段（50Hz/15 字段轮转，
 * 每字段约 3.3Hz）。四囊独立执行器构型（每囊 1 风机 + 1 阀门，PWM_AUX 201-208）：
 *   "buoy"    → netBuoyancy   (净浮力调整量 N，正=上升)
 *   "alt_err" → altitudeError (高度误差 m)
 *   "b_mass"  → ballastMass   (单囊空气质量 kg，0 ~ BALLOON_M_MAX=128.5)
 *   "blower0" → blower0       (左副囊风机占空比 0-100，0=停)
 *   "blower1" → blower1       (左主囊风机占空比 0-100)
 *   "blower2" → blower2       (右主囊风机占空比 0-100)
 *   "blower3" → blower3       (右副囊风机占空比 0-100)
 *   "valve0"  → valve0        (左副囊阀门 0=关 / 100=开，常闭阀，PWM 模拟开关量)
 *   "valve1"  → valve1        (左主囊阀门)
 *   "valve2"  → valve2        (右主囊阀门)
 *   "valve3"  → valve3        (右副囊阀门)
 *   "bal_p0"  → bladderPressure0 (左副囊表压 kPa，0~5.0，>4.75 接近超压)
 *   "bal_p1"  → bladderPressure1 (左主囊表压 kPa)
 *   "bal_p2"  → bladderPressure2 (右主囊表压 kPa)
 *   "bal_p3"  → bladderPressure3 (右副囊表压 kPa)
 *
 * 压差数据链: LoRa压力传感器x4 → 树莓派 → uXRCE-DDS → 飞控 → NAMED_VALUE_FLOAT。
 * 压差/风机/阀门 Fact 初始值为 NaN（未收到数据），台架未充压时压差为小负值零漂属正常。
 */
class AirshipBallastFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *netBuoyancy      READ netBuoyancy      CONSTANT)
    Q_PROPERTY(Fact *altitudeError    READ altitudeError    CONSTANT)
    Q_PROPERTY(Fact *ballastMass      READ ballastMass      CONSTANT)
    Q_PROPERTY(Fact *blower0          READ blower0          CONSTANT)
    Q_PROPERTY(Fact *blower1          READ blower1          CONSTANT)
    Q_PROPERTY(Fact *blower2          READ blower2          CONSTANT)
    Q_PROPERTY(Fact *blower3          READ blower3          CONSTANT)
    Q_PROPERTY(Fact *valve0           READ valve0           CONSTANT)
    Q_PROPERTY(Fact *valve1           READ valve1           CONSTANT)
    Q_PROPERTY(Fact *valve2           READ valve2           CONSTANT)
    Q_PROPERTY(Fact *valve3           READ valve3           CONSTANT)
    Q_PROPERTY(Fact *bladderPressure0 READ bladderPressure0 CONSTANT)
    Q_PROPERTY(Fact *bladderPressure1 READ bladderPressure1 CONSTANT)
    Q_PROPERTY(Fact *bladderPressure2 READ bladderPressure2 CONSTANT)
    Q_PROPERTY(Fact *bladderPressure3 READ bladderPressure3 CONSTANT)

public:
    explicit AirshipBallastFactGroup(QObject *parent = nullptr);

    Fact *netBuoyancy()      { return &_netBuoyancyFact; }
    Fact *altitudeError()    { return &_altitudeErrorFact; }
    Fact *ballastMass()      { return &_ballastMassFact; }
    Fact *blower0()          { return &_blower0Fact; }
    Fact *blower1()          { return &_blower1Fact; }
    Fact *blower2()          { return &_blower2Fact; }
    Fact *blower3()          { return &_blower3Fact; }
    Fact *valve0()           { return &_valve0Fact; }
    Fact *valve1()           { return &_valve1Fact; }
    Fact *valve2()           { return &_valve2Fact; }
    Fact *valve3()           { return &_valve3Fact; }
    Fact *bladderPressure0() { return &_bladderPressure0Fact; }
    Fact *bladderPressure1() { return &_bladderPressure1Fact; }
    Fact *bladderPressure2() { return &_bladderPressure2Fact; }
    Fact *bladderPressure3() { return &_bladderPressure3Fact; }

    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) override;

private:
    Fact _netBuoyancyFact      {0, QStringLiteral("netBuoyancy"),      FactMetaData::valueTypeDouble};
    Fact _altitudeErrorFact    {0, QStringLiteral("altitudeError"),    FactMetaData::valueTypeDouble};
    Fact _ballastMassFact      {0, QStringLiteral("ballastMass"),      FactMetaData::valueTypeDouble};
    Fact _blower0Fact          {0, QStringLiteral("blower0"),          FactMetaData::valueTypeDouble};
    Fact _blower1Fact          {0, QStringLiteral("blower1"),          FactMetaData::valueTypeDouble};
    Fact _blower2Fact          {0, QStringLiteral("blower2"),          FactMetaData::valueTypeDouble};
    Fact _blower3Fact          {0, QStringLiteral("blower3"),          FactMetaData::valueTypeDouble};
    Fact _valve0Fact           {0, QStringLiteral("valve0"),           FactMetaData::valueTypeDouble};
    Fact _valve1Fact           {0, QStringLiteral("valve1"),           FactMetaData::valueTypeDouble};
    Fact _valve2Fact           {0, QStringLiteral("valve2"),           FactMetaData::valueTypeDouble};
    Fact _valve3Fact           {0, QStringLiteral("valve3"),           FactMetaData::valueTypeDouble};
    Fact _bladderPressure0Fact {0, QStringLiteral("bladderPressure0"), FactMetaData::valueTypeDouble};
    Fact _bladderPressure1Fact {0, QStringLiteral("bladderPressure1"), FactMetaData::valueTypeDouble};
    Fact _bladderPressure2Fact {0, QStringLiteral("bladderPressure2"), FactMetaData::valueTypeDouble};
    Fact _bladderPressure3Fact {0, QStringLiteral("bladderPressure3"), FactMetaData::valueTypeDouble};
};
