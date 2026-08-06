#include "AirshipSettingsTest.h"

#include <QtCore/QSettings>
#include <QtTest/QSignalSpy>

#include "Fact.h"
#include "FactValueGrid.h"
#include "FlyViewSettings.h"
#include "MockLink.h"
#include "MultiVehicleManager.h"
#include "SettingsManager.h"
#include "Vehicle.h"

// FactValueGrid 的 _settingsGroup/_specificVehicleForCard 是 protected 成员，
// 通过子类在测试中注入，无需经过 QML 运行时。
class TestFactValueGrid : public FactValueGrid
{
public:
    using FactValueGrid::FactValueGrid;

    void configureForTest(const QString& settingsGroup, Vehicle* vehicle)
    {
        _settingsGroup = settingsGroup;
        _specificVehicleForCard = vehicle;
    }
};

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

void AirshipSettingsTest::_resetToDefaults_removesVehicleClassGroup_test()
{
    // MultiVehicleManager::init() 建立 MAVLinkProtocol::vehicleHeartbeatInfo -> _vehicleHeartbeatInfo
    // 的连接，以便在 heartbeat 到达时创建 Vehicle。VehicleTest 在其 init() 中调用，
    // 此处需手动确保（否则 heartbeat 到达时 vehicles 始终为 0，activeVehicleChanged 永不发出）。
    MultiVehicleManager::instance()->init();

    // 连接飞艇 MockLink，使 activeVehicle 为飞艇（MAV_TYPE_AIRSHIP = 7）。
    QSignalSpy spyVehicle(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged);
    QVERIFY(spyVehicle.isValid());
    MockLink *link = MockLink::startAirshipMockLink(false /* sendStatusText */, false /* enableCamera */, false /* enableGimbal */);
    QVERIFY(link);
    QVERIFY(UnitTest::waitForSignal(spyVehicle, TestTimeout::longMs(), QStringLiteral("activeVehicleChanged")));
    Vehicle *vehicle = MultiVehicleManager::instance()->activeVehicle();
    QVERIFY(vehicle);
    QCOMPARE(vehicle->vehicleType(), MAV_TYPE_AIRSHIP);

    // FactValueGrid 实际保存用 _settingsKey() = "<settingsGroup>-<vehicleClass>"，
    // 飞艇 vehicleClass 后缀为 MAV_TYPE_AIRSHIP(=7)。
    const QString persistedGroup = QStringLiteral("AirshipInstr.Page0-7");

    // 模拟：某页已持久化（老 bug 下 resetToDefaults 删不掉此 group，形成幽灵配置）。
    {
        QSettings settings;
        settings.beginGroup(persistedGroup);
        settings.setValue(QStringLiteral("version"), 1);
        settings.setValue(QStringLiteral("rowCount"), 2);
        settings.endGroup();
        QVERIFY(QSettings().childGroups().contains(persistedGroup));
    }

    TestFactValueGrid grid;
    grid.configureForTest(QStringLiteral("AirshipInstr.Page0"), vehicle);
    grid.resetToDefaults();

    // 回归断言：带 vehicleClass 后缀的持久化 group 必须被删除。
    QVERIFY2(!QSettings().childGroups().contains(persistedGroup),
             "resetToDefaults() must remove the vehicleClass-suffixed QSettings group");

    // 断开 MockLink，清理 vehicle。
    link->disconnect();
    QVERIFY(UnitTest::waitForSignal(spyVehicle, TestTimeout::longMs(), QStringLiteral("activeVehicleChanged")));
}

UT_REGISTER_TEST(AirshipSettingsTest, TestLabel::Unit)
