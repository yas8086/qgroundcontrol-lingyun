#pragma once

#include "FactGroup.h"

/**
 * @brief 飞艇浮力控制状态 FactGroup
 *
 * 接收 PX4 通过 NAMED_VALUE_FLOAT 消息发送的 ballast_setpoint 字段，
 * 转换为 QGC Fact 供 FlyView 仪表盘显示。
 *
 * NAMED_VALUE_FLOAT name 映射：
 *   "buoy"    → netBuoyancy   (净浮力 N)
 *   "blw_l"   → blowerLeft    (左鼓风机 [0,1])
 *   "blw_r"   → blowerRight   (右鼓风机 [0,1])
 *   "vlv_l"   → valveLeft     (左阀门 [0,1])
 *   "vlv_r"   → valveRight    (右阀门 [0,1])
 *   "alt_err" → altitudeError (高度误差 m)
 */
class AirshipBallastFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *netBuoyancy   READ netBuoyancy   CONSTANT)
    Q_PROPERTY(Fact *blowerLeft    READ blowerLeft    CONSTANT)
    Q_PROPERTY(Fact *blowerRight   READ blowerRight   CONSTANT)
    Q_PROPERTY(Fact *valveLeft     READ valveLeft     CONSTANT)
    Q_PROPERTY(Fact *valveRight    READ valveRight    CONSTANT)
    Q_PROPERTY(Fact *altitudeError READ altitudeError CONSTANT)

public:
    explicit AirshipBallastFactGroup(QObject *parent = nullptr);

    Fact *netBuoyancy()    { return &_netBuoyancyFact; }
    Fact *blowerLeft()     { return &_blowerLeftFact; }
    Fact *blowerRight()    { return &_blowerRightFact; }
    Fact *valveLeft()      { return &_valveLeftFact; }
    Fact *valveRight()     { return &_valveRightFact; }
    Fact *altitudeError() { return &_altitudeErrorFact; }

    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) override;

private:
    Fact _netBuoyancyFact    {0, QStringLiteral("netBuoyancy"),   FactMetaData::valueTypeDouble};
    Fact _blowerLeftFact     {0, QStringLiteral("blowerLeft"),    FactMetaData::valueTypeDouble};
    Fact _blowerRightFact    {0, QStringLiteral("blowerRight"),   FactMetaData::valueTypeDouble};
    Fact _valveLeftFact      {0, QStringLiteral("valveLeft"),     FactMetaData::valueTypeDouble};
    Fact _valveRightFact     {0, QStringLiteral("valveRight"),    FactMetaData::valueTypeDouble};
    Fact _altitudeErrorFact  {0, QStringLiteral("altitudeError"), FactMetaData::valueTypeDouble};
};
