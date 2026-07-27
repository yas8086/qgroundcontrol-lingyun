import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

Item {
    id: testRoot
    width: 400; height: 300

    // QGC QML 测试框架限制（brief 修正 #3）：QGCQmlQuickTests 进程未链接
    // QGroundControlModule/FlyViewModule 的 qrc 资源，qmldir `prefer :/qml/...`
    // 让 Qt 优先从 qrc 加载 QML 文件，但测试进程无该 qrc，导致所有 QGC 类型
    // （含 AirshipPagedValuesBar、QGCPalette 等）在测试进程不可用。
    //
    // 应对策略：
    //   1) 用 Loader.source URL 字符串而非 sourceComponent+Component{AirshipPagedValuesBar}：
    //      后者会在 QML 编译期解析 AirshipPagedValuesBar 类型，触发 compile() FAIL；
    //      source 是字符串，编译期不解析类型，编译通过。
    //   2) initTestCase 探测 QGroundControl singleton，不可用则 skip + 置 _qgcReady=false。
    //      注意：Qt6 QML TestCase 的 skip() 在 initTestCase 中只跳过 initTestCase 自身，
    //      不跳过其他测试函数（与 Qt5/文档描述不同），故每个 test_xxx 需自行检查 _qgcReady。
    //   3) 运行时分页逻辑验证延后到 Task 7 端到端（启动 QGC+MockLink 飞艇实测）。
    //   4) 保留 brief 的断言逻辑，未来框架支持时（QGCQmlQuickTests 链接资源或 qmldir 不
    //      prefer qrc）自动启用。
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

        function test_defaultPageCount() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            compare(barLoader.item.pageCount, 3, "default 3 pages")
        }

        function test_appendDelete() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var bar = barLoader.item
            var initial = bar.pageCount
            bar.appendPage()
            compare(bar.pageCount, initial + 1, "page added")
            bar.deleteLastPage()
            compare(bar.pageCount, initial, "page removed back to initial")
        }

        function test_defaultValuesLoadedOnEmptyPage() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var bar = barLoader.item
            var page0 = bar.swipeView.itemAt(0)
            verify(page0, "page 0 exists")
            var grid = page0.factValueGrid
            verify(grid, "page 0 has factValueGrid")
            if (grid.columns.count === 0) {
                page0._loadAirshipDefaults(0)
            }
            verify(grid.columns.count > 0, "default values loaded")
        }

        function test_pageCountClamped() {
            if (!_qgcReady) skip("QGroundControl singleton not available in QGCQmlQuickTests process")
            var bar = barLoader.item
            while (bar.pageCount > 1) bar.deleteLastPage()
            compare(bar.pageCount, 1, "min 1 page")
            bar.deleteLastPage()
            compare(bar.pageCount, 1, "cannot go below 1 page")
            while (bar.pageCount < 5) bar.appendPage()
            compare(bar.pageCount, 5, "max 5 pages")
            bar.appendPage()
            compare(bar.pageCount, 5, "cannot exceed 5 pages")
        }
    }
}
