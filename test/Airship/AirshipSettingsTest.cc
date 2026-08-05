#include "AirshipSettingsTest.h"

#include "Fact.h"
#include "FlyViewSettings.h"
#include "SettingsManager.h"

// 飞艇 settings 默认值（与 src/Settings/FlyView.SettingsGroup.json 保持一致）。
// JSON 是 single source of truth，这里断言默认值可捕获 JSON 被误改的回归。

void AirshipSettingsTest::_airshipInstrumentPageCount_default_test()
{
    FlyViewSettings *flyView = SettingsManager::instance()->flyViewSettings();
    QVERIFY(flyView);
    Fact *fact = flyView->airshipInstrumentPageCount();
    QVERIFY(fact);
    // FlyView.SettingsGroup.json: airshipInstrumentPageCount default = 3
    QCOMPARE(fact->rawValue().toUInt(), 3u);
}

void AirshipSettingsTest::_airshipShowTelemetryBar_default_test()
{
    FlyViewSettings *flyView = SettingsManager::instance()->flyViewSettings();
    QVERIFY(flyView);
    Fact *fact = flyView->airshipShowTelemetryBar();
    QVERIFY(fact);
    // FlyView.SettingsGroup.json: airshipShowTelemetryBar default = true
    QCOMPARE(fact->rawValue().toBool(), true);
}

void AirshipSettingsTest::_airshipInstrumentPageCount_readWrite_test()
{
    FlyViewSettings *flyView = SettingsManager::instance()->flyViewSettings();
    QVERIFY(flyView);
    Fact *fact = flyView->airshipInstrumentPageCount();
    QVERIFY(fact);

    const uint32_t original = fact->rawValue().toUInt();
    const uint32_t newValue = (original == 5u) ? 4u : 5u;  // 避免与原值相同

    fact->setRawValue(newValue);
    QCOMPARE(fact->rawValue().toUInt(), newValue);

    // 恢复原值，避免影响其他测试
    fact->setRawValue(original);
    QCOMPARE(fact->rawValue().toUInt(), original);
}

void AirshipSettingsTest::_airshipShowTelemetryBar_readWrite_test()
{
    FlyViewSettings *flyView = SettingsManager::instance()->flyViewSettings();
    QVERIFY(flyView);
    Fact *fact = flyView->airshipShowTelemetryBar();
    QVERIFY(fact);

    const bool original = fact->rawValue().toBool();
    fact->setRawValue(!original);
    QCOMPARE(fact->rawValue().toBool(), !original);

    // 恢复原值
    fact->setRawValue(original);
    QCOMPARE(fact->rawValue().toBool(), original);
}

UT_REGISTER_TEST(AirshipSettingsTest, TestLabel::Unit)
