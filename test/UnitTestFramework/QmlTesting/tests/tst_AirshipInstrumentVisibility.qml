import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

/// Tests for the airship press-and-hold panel visibility popup on
/// FlyViewInstrumentPanel (task-5).
///
/// Note: QGCQmlQuickTests is an isolated Qt6 executable that does not link
/// QGroundControlModule/FlyViewModule, so the QGroundControl QML singleton
/// (and the qrc that ships FlyViewInstrumentPanel.qml) is not available in
/// this process. The Loader below therefore stays inactive when the singleton
/// is absent, and each test skips. Runtime verification of the press-and-hold
/// popup (gesture + dialog open) is deferred to Task 7 (end-to-end with QGC +
/// MockLink airship), since the Qt Quick Test framework cannot synthesize a
/// real pressAndHold gesture across the reparented QGCMouseArea stack. The
/// test here only verifies the underlying settings fact remains read/write
/// so the popup's bound switches stay functional.
Rectangle {
    id: testRoot
    width: 200; height: 200

    // QGC QML 测试框架限制（brief 修正 #3）：QGCQmlQuickTests 进程未链接
    // QGroundControlModule/FlyViewModule 的 qrc 资源，FlyViewInstrumentPanel
    // 等类型在测试进程不可用。
    //
    // 应对策略：
    //   1) 用 Loader.source URL 字符串而非 sourceComponent+Component{...}：
    //      后者会在 QML 编译期解析类型，触发 compile() FAIL；source 是字符串，
    //      编译期不解析类型，编译通过。
    //   2) initTestCase 探测 QGroundControl singleton，不可用则 skip + return。
    //      注意：Qt6 QML TestCase 的 skip() 在 initTestCase 中只跳过 initTestCase
    //      自身，不跳过其他测试函数，故每个 test_xxx 需自行检查 _qgcReady。
    //   3) 运行时长按弹窗 UI 交互验证延后到 Task 7 端到端。
    property bool _qgcReady: false

    Loader {
        id: panelLoader
        active: false  // initTestCase 探测通过后才激活
        source: "qrc:/qml/QGroundControl/FlyView/FlyViewInstrumentPanel.qml"
    }

    TestCase {
        name: "AirshipInstrumentVisibilityTest"
        when: windowShown

        function initTestCase() {
            if (typeof QGroundControl === "undefined" || !QGroundControl.settingsManager) {
                skip("QGroundControl singleton not available in QGCQmlQuickTests process")
                return
            }
            panelLoader.active = true
            tryCompare(panelLoader, "status", Loader.Ready, 2000)
            _qgcReady = true
        }

        function test_airshipShowTelemetryBar_setting() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var settings = QGroundControl.settingsManager.flyViewSettings
            var before = settings.airshipShowTelemetryBar.rawValue
            settings.airshipShowTelemetryBar.rawValue = !before
            compare(settings.airshipShowTelemetryBar.rawValue, !before, "telemetry bar toggle persisted")
            settings.airshipShowTelemetryBar.rawValue = before
            compare(settings.airshipShowTelemetryBar.rawValue, before, "restored")
        }
    }
}
