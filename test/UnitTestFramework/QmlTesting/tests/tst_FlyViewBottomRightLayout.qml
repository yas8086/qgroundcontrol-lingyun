import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

/// Regression guard for FlyViewBottomRightRowLayout airship branch (task-4).
///
/// QGC QML 测试框架限制（brief 修正 #3）：QGCQmlQuickTests 进程未链接
/// QGroundControlModule/FlyViewModule 的 qrc 资源，qmldir `prefer :/qml/...`
/// 让 Qt 优先从 qrc 加载 QML 文件，但测试进程无该 qrc，导致所有 QGC 类型
/// （含 FlyViewBottomRightRowLayout、TelemetryValuesBar、AirshipPagedValuesBar）
/// 在测试进程不可用。
///
/// 应对策略（与 tst_AirshipPagedValuesBar.qml 一致）：
///   1) 用 Loader.source URL 字符串而非 sourceComponent+Component{...}：
///      后者会在 QML 编译期解析 FlyViewBottomRightRowLayout 类型，触发 compile() FAIL；
///      source 是字符串，编译期不解析类型，编译通过。
///   2) initTestCase 探测 QGroundControl singleton，不可用则 skip + 置 _qgcReady=false。
///      注意：Qt6 QML TestCase 的 skip() 在 initTestCase 中只跳过 initTestCase 自身，
///      不跳过其他测试函数（与 Qt5/文档描述不同），故每个 test_xxx 需自行检查 _qgcReady。
///   3) 运行时飞艇分支验证延后到 Task 7 端到端（启动 QGC+MockLink 飞艇实测）。
///   4) 保留 brief 的断言逻辑，未来框架支持时自动启用。
Item {
    id: testRoot
    width: 800; height: 600

    property bool _qgcReady: false

    Loader {
        id: layoutLoader
        active: false  // initTestCase 探测通过后才激活
        source: "qrc:/qml/QGroundControl/FlyView/FlyViewBottomRightRowLayout.qml"
    }

    TestCase {
        name: "FlyViewBottomRightLayoutTest"
        when: windowShown

        function initTestCase() {
            if (typeof QGroundControl === "undefined" || !QGroundControl.settingsManager) {
                skip("QGroundControl singleton not available in QGCQmlQuickTests process")
                return
            }
            layoutLoader.active = true
            tryCompare(layoutLoader, "status", Loader.Ready, 2000)
            _qgcReady = true
        }

        // 无飞艇时（默认 activeVehicle null/非飞艇）布局应成功加载。
        // 飞艇分支 Loader.active=false（不加载 AirshipPagedValuesBar），
        // 原生 TelemetryValuesBar 可见。运行时验证延后 Task 7。
        // 注：initTestCase SKIP 后，Qt6 QtTest 对首个测试函数仅输出 entering
        // 而不执行函数体（与 tst_AirshipPagedValuesBar::test_appendDelete 行为
        // 一致），属框架限制，运行时验证延后 Task 7。
        function test_noAirshipLoadsTelemetryBar() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            verify(layoutLoader.item, "layout loaded")
        }
    }
}
