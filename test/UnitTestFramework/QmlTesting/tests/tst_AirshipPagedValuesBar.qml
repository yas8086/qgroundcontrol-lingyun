import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

Item {
    id: testRoot
    width: 400; height: 300

    // QGC QML 测试框架限制：QGCQmlQuickTests 进程未链接 FlyViewModule 的 qrc 资源，
    // QGroundControl singleton 在该进程不可用，运行时断言一律 skip。
    // 真正的 settings 默认值验证在 C++ AirshipSettingsTest 中执行（避免假绿）。
    //
    // 组件现为并排布局：三主题页（飞行核心/浮力/能源）横向排开，
    // 每页单列 ≤3 行（FactValueGrid.maxColumns/maxRows 硬限制），
    // 页面显隐由 FlyViewSettings.airshipShowPage* 三个 bool 控制。
    property bool _qgcReady: false

    Loader {
        id: barLoader
        active: false  // initTestCase 探测通过后才激活
        source: "qrc:/qml/QGroundControl/FlyView/AirshipPagedValuesBar.qml"
    }

    TestCase {
        name: "AirshipPagedValuesBarTest"
        when: windowShown

        function initTestCase() {
            if (typeof QGroundControl === "undefined" || !QGroundControl.settingsManager) {
                skip("QGroundControl singleton not available in QGCQmlQuickTests process")
                return
            }
            barLoader.active = true
            tryCompare(barLoader, "status", Loader.Ready, 2000)
            _qgcReady = true
        }

        function test_componentLoads() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            verify(barLoader.item, "AirshipPagedValuesBar loaded")
        }

        function test_pageVisibilityDefaults() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var flyView = QGroundControl.settingsManager.flyViewSettings
            compare(flyView.airshipShowPageFlightCore.rawValue, true, "flight core page visible by default")
            compare(flyView.airshipShowPageBuoyancy.rawValue, true, "buoyancy page visible by default")
            compare(flyView.airshipShowPageEnergy.rawValue, true, "energy page visible by default")
        }

        function test_pageVisibilityToggle() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var flyView = QGroundControl.settingsManager.flyViewSettings
            var original = flyView.airshipShowPageFlightCore.rawValue
            flyView.airshipShowPageFlightCore.rawValue = !original
            compare(flyView.airshipShowPageFlightCore.rawValue, !original, "flight core toggle persisted")
            flyView.airshipShowPageFlightCore.rawValue = original
            compare(flyView.airshipShowPageFlightCore.rawValue, original, "flight core restored")
        }
    }
}
