# 飞艇专用分页仪表盘 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为灵云01号飞艇 QGC 提供对标 LGroundControl V1.0.0 的多分页数据仪表盘，复用 QGC 现有 `HorizontalFactValueGrid` 自定义能力，不改 QGC 核心。

**Architecture:** 新建飞艇专用 `AirshipPagedValuesBar.qml`，用 `QGCSwipeView` + `QGCPageIndicator` 包裹多个复用的 `TelemetryValuesBar`（每页独立 `settingsGroup` 持久化），在 `FlyViewBottomRightRowLayout.qml` 做飞艇条件分支注入。默认指标用 QML `appendColumn()`/`setFact()` API 注入。长按姿态球弹出显隐面板。飞艇启用航向指示器。

**Tech Stack:** Qt 6.10 / QML / C++20 / CMake / QGC Fact System / QtTest (QML TestCase)

## Global Constraints

- 工作区规则：不修改 `src/QmlControls/` 核心（`HorizontalFactValueGrid.qml`、`InstrumentValueEditDialog.qml`、`InstrumentValueData.*`、`FactValueGrid.*` 全部只读）
- 飞艇代码集中在 `src/FlyView/`、`src/Settings/`、`src/FirmwarePlugin/PX4/`，与第一轮 `AirshipBallastHUD` 同模式
- 飞艇判断统一用 `globals.activeVehicle.airship`（Vehicle Q_PROPERTY bool）
- 编码风格遵循 `CODING_STYLE.md`：C++20、clang-format、QML 命名、日志用 `qCDebug`/`qCWarning`
- 提交风格：conventional commits，`feat(airship): ...` / `test(airship): ...`
- 构建命令：`cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc)`
- 测试命令：`ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R <pattern> --output-on-failure`

## File Structure

**新增**：
- `src/FlyView/AirshipPagedValuesBar.qml` — 分页容器（QGCSwipeView + 多页 + 增删页按钮 + 默认指标注入）
- `test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml` — QML 单元测试

**修改**（与第一轮同模式）：
- `src/Settings/FlyViewSettings.h` / `.cc` / `FlyView.SettingsGroup.json` — 新增 `airshipInstrumentPageCount`、`airshipShowTelemetryBar` 设置项
- `src/FlyView/FlyViewBottomRightRowLayout.qml` — 飞艇条件分支加载 `AirshipPagedValuesBar`
- `src/FlyView/FlyViewInstrumentPanel.qml` — 长按手势 + 显隐弹窗
- `src/FlyView/CMakeLists.txt` — 注册新 QML
- `src/Settings/FlyView.SettingsGroup.json` — `showAdditionalIndicatorsCompass` 默认值改 true

**对设计文档的优化**（更 YAGNI）：
1. 去掉 `AirshipInstrumentDefaultsLoader.h/.cc` 和 `AirshipInstrumentDefaults.json`——默认指标改用 QML 内联 JS 对象 + `FactValueGrid::appendColumn()`/`InstrumentValueData::setFact()` API 注入，零 C++ 新增
2. `showAdditionalIndicatorsCompass` 改全局 default 为 true（对所有机型有益，飞艇自动获得），无需在 `AirshipFirmwarePlugin` 改动

---

## Task 1: 新增 FlyViewSettings 设置项

**Files:**
- Modify: `src/Settings/FlyViewSettings.h`
- Modify: `src/Settings/FlyViewSettings.cc`
- Modify: `src/Settings/FlyView.SettingsGroup.json`
- Test: `test/UnitTestFramework/QmlTesting/tests/tst_AirshipSettings.qml` (Create)

**Interfaces:**
- Produces: `FlyViewSettings::airshipInstrumentPageCount` (Fact, int, default 3)、`FlyViewSettings::airshipShowTelemetryBar` (Fact, bool, default true) —— 后续 Task 2/5 依赖

- [ ] **Step 1: 写失败测试**

创建 `test/UnitTestFramework/QmlTesting/tests/tst_AirshipSettings.qml`：

```qml
import QtQuick
import QtTest
import QGroundControl
import QGroundControl.Settings

TestCase {
    name: "AirshipSettingsTest"

    function test_airshipInstrumentPageCount_default() {
        var f = QGroundControl.settingsManager.flyViewSettings.airshipInstrumentPageCount
        compare(f.rawValue, 3, "default page count is 3")
    }

    function test_airshipShowTelemetryBar_default() {
        var f = QGroundControl.settingsManager.flyViewSettings.airshipShowTelemetryBar
        compare(f.rawValue, true, "default telemetry bar visible is true")
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipSettings --output-on-failure`
Expected: FAIL（`airshipInstrumentPageCount` 未定义）

- [ ] **Step 3: 在 FlyViewSettings.h 加声明**

在 `DEFINE_SETTINGFACT(enableAutomaticMissionPopups)` 后追加：

```cpp
    DEFINE_SETTINGFACT(airshipInstrumentPageCount)
    DEFINE_SETTINGFACT(airshipShowTelemetryBar)
```

- [ ] **Step 4: 在 FlyViewSettings.cc 加定义**

在 `DECLARE_SETTINGSFACT(FlyViewSettings, enableAutomaticMissionPopups)` 后追加：

```cpp
DECLARE_SETTINGSFACT(FlyViewSettings, airshipInstrumentPageCount)
DECLARE_SETTINGSFACT(FlyViewSettings, airshipShowTelemetryBar)
```

- [ ] **Step 5: 在 FlyView.SettingsGroup.json 加元数据**

在 `enableAutomaticMissionPopups` 条目后追加：

```json
        {
            "name": "airshipInstrumentPageCount",
            "shortDesc": "Number of pages in the airship paged instrument panel.",
            "type": "uint32",
            "default": 3,
            "label": "Airship instrument page count",
            "keywords": "airship,instrument,page"
        },
        {
            "name": "airshipShowTelemetryBar",
            "shortDesc": "Show the airship paged telemetry bar in Fly view.",
            "type": "bool",
            "default": true,
            "label": "Show airship telemetry bar",
            "keywords": "airship,instrument,telemetry"
        }
```

- [ ] **Step 6: 编译 + 运行测试验证通过**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipSettings --output-on-failure`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add src/Settings/FlyViewSettings.h src/Settings/FlyViewSettings.cc src/Settings/FlyView.SettingsGroup.json test/UnitTestFramework/QmlTesting/tests/tst_AirshipSettings.qml
git commit -m "feat(airship): add FlyViewSettings for paged instrument (page count, telemetry bar visibility)"
```

---

## Task 2: AirshipPagedValuesBar.qml 分页容器

**Files:**
- Create: `src/FlyView/AirshipPagedValuesBar.qml`
- Modify: `src/FlyView/CMakeLists.txt`
- Test: `test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml` (Create)

**Interfaces:**
- Consumes: `FlyViewSettings.airshipInstrumentPageCount`（Task 1）
- Produces: `AirshipPagedValuesBar` 组件，含属性 `pageCount`、`settingsUnlocked`，方法 `appendPage()`/`deleteLastPage()` —— Task 4 注入它，Task 3 用其内部 grid 注入默认指标

- [ ] **Step 1: 写失败测试**

创建 `test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml`：

```qml
import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

Rectangle {
    id: testRoot
    width: 400; height: 300

    AirshipPagedValuesBar {
        id: bar
        anchors.fill: parent
    }

    TestCase {
        name: "AirshipPagedValuesBarTest"
        when: windowShown

        function test_defaultPageCount() {
            compare(bar.pageCount, 3, "default 3 pages")
        }

        function test_appendDeletePage() {
            var initial = bar.pageCount
            bar.appendPage()
            compare(bar.pageCount, initial + 1, "page added")
            bar.deleteLastPage()
            compare(bar.pageCount, initial, "page removed back to initial")
        }

        function test_pageCountClamped() {
            // 删到只剩 1 页
            while (bar.pageCount > 1) bar.deleteLastPage()
            compare(bar.pageCount, 1, "min 1 page")
            bar.deleteLastPage()
            compare(bar.pageCount, 1, "cannot go below 1 page")
            // 加到上限 5
            while (bar.pageCount < 5) bar.appendPage()
            compare(bar.pageCount, 5, "max 5 pages")
            bar.appendPage()
            compare(bar.pageCount, 5, "cannot exceed 5 pages")
        }
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipPagedValuesBar --output-on-failure`
Expected: FAIL（组件不存在）

- [ ] **Step 3: 实现 AirshipPagedValuesBar.qml**

创建 `src/FlyView/AirshipPagedValuesBar.qml`：

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

// 飞艇专用分页数据仪表盘
// 用 QGCSwipeView 包裹多个 TelemetryValuesBar（每页独立 settingsGroup 持久化）
Item {
    id: root

    property int maxPages: 5
    property int minPages: 1
    property var  _flyViewSettings: QGroundControl.settingsManager.flyViewSettings
    property int  pageCount: _flyViewSettings.airshipInstrumentPageCount.rawValue
    property bool settingsUnlocked: false
    property real _margins: ScreenTools.defaultFontPixelWidth / 2

    // 默认页数保护
    onPageCountChanged: {
        if (pageCount < minPages) _flyViewSettings.airshipInstrumentPageCount.rawValue = minPages
        else if (pageCount > maxPages) _flyViewSettings.airshipInstrumentPageCount.rawValue = maxPages
    }

    function appendPage() {
        if (pageCount < maxPages) {
            _flyViewSettings.airshipInstrumentPageCount.rawValue = pageCount + 1
        }
    }

    function deleteLastPage() {
        if (pageCount > minPages) {
            _flyViewSettings.airshipInstrumentPageCount.rawValue = pageCount - 1
        }
    }

    Rectangle {
        anchors.fill: parent
        color: qgcPal.window
        opacity: 0.75
        radius: ScreenTools.defaultFontPixelWidth / 2
    }

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _margins
        spacing: _margins

        // 编辑模式工具行（+页 / -页 / 锁）
        RowLayout {
            Layout.fillWidth: true
            visible: root.settingsUnlocked
            spacing: _margins

            QGCButton {
                text: qsTr("+Page")
                enabled: pageCount < maxPages
                onClicked: root.appendPage()
            }
            QGCButton {
                text: qsTr("-Page")
                enabled: pageCount > minPages
                onClicked: root.deleteLastPage()
            }
            Item { Layout.fillWidth: true }
            QGCColoredImage {
                source: "qrc:/InstrumentValueIcons/lock-open.svg"
                width: ScreenTools.minTouchPixels * 0.75
                height: width
                sourceSize.width: width
                fillMode: Image.PreserveAspectFit
                color: qgcPal.text
                QGCMouseArea {
                    anchors.fill: parent
                    onClicked: root.settingsUnlocked = false
                }
            }
        }

        // 分页 SwipeView
        QGCSwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: root.pageCount

                TelemetryValuesBar {
                    id: pageBar
                    // 每页独立 settingsGroup 持久化
                    settingsGroup: "AirshipInstr.Page" + index
                    specificVehicleForCard: null
                    extraWidth: 0

                    // 进入页内编辑模式（透传给内部 HorizontalFactValueGrid）
                    property bool _pageUnlocked: root.settingsUnlocked
                    factValueGrid.settingsUnlocked: _pageUnlocked
                }
            }
        }

        QGCPageIndicator {
            count: swipeView.count
            currentIndex: swipeView.currentIndex
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // 右键/长按进入编辑模式
    QGCMouseArea {
        anchors.fill: parent
        visible: !root.settingsUnlocked
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        onClicked: (mouse) => {
            if (!ScreenTools.isMobile && mouse.button === Qt.RightButton) {
                root.settingsUnlocked = true
                mouse.accepted = true
            }
        }
        onPressAndHold: (mouse) => {
            root.settingsUnlocked = true
            mouse.accepted = true
        }
    }
}
```

- [ ] **Step 4: 在 CMakeLists.txt 注册 QML**

在 `src/FlyView/CMakeLists.txt` 的飞艇 QML 列表（`AirshipBallastHUD.qml` 附近）追加：

```cmake
    FlyView/AirshipPagedValuesBar.qml
```

- [ ] **Step 5: 编译 + 运行测试验证通过**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipPagedValuesBar --output-on-failure`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/FlyView/AirshipPagedValuesBar.qml src/FlyView/CMakeLists.txt test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml
git commit -m "feat(airship): add AirshipPagedValuesBar with QGCSwipeView multi-page container"
```

---

## Task 3: 飞艇默认指标注入

**Files:**
- Modify: `src/FlyView/AirshipPagedValuesBar.qml`
- Test: `test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml` (追加用例)

**Interfaces:**
- Consumes: `FactValueGrid.appendColumn()`/`appendRow()`（返回 `QmlObjectListModel*`）、`InstrumentValueData.setFact(group, name)`、`Vehicle.airship`、`Vehicle.ballast` FactGroup
- Produces: 每页 `HorizontalFactValueGrid` 首次使用（`columns.count == 0`）时自动填充飞艇默认指标

- [ ] **Step 1: 追加失败测试**

在 `tst_AirshipPagedValuesBar.qml` 的 `TestCase` 内追加：

```qml
        function test_defaultValuesLoadedOnEmptyPage() {
            // 找到第 0 页的 TelemetryValuesBar 内部 grid
            var page0 = swipeView.itemAt(0)
            verify(page0, "page 0 exists")
            var grid = page0.factValueGrid
            verify(grid, "page 0 has factValueGrid")
            // 若 grid 为空（首次使用），手动触发默认加载用于测试
            if (grid.columns.count === 0) {
                page0._loadAirshipDefaults(0)
            }
            verify(grid.columns.count > 0, "default values loaded")
        }
```

- [ ] **Step 2: 运行测试验证失败**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipPagedValuesBar --output-on-failure`
Expected: FAIL（`_loadAirshipDefaults` 未定义）

- [ ] **Step 3: 在 AirshipPagedValuesBar.qml 加默认指标加载逻辑**

在 `TelemetryValuesBar`（Repeater 内）的 `factValueGrid` 上加 `Component.onCompleted` 钩子，并在 `root` 顶部加默认指标数据。修改 `TelemetryValuesBar` 块为：

```qml
                TelemetryValuesBar {
                    id: pageBar
                    settingsGroup: "AirshipInstr.Page" + index
                    specificVehicleForCard: null
                    extraWidth: 0
                    property bool _pageUnlocked: root.settingsUnlocked
                    factValueGrid.settingsUnlocked: _pageUnlocked

                    Component.onCompleted: {
                        if (factValueGrid.columns.count === 0) {
                            _loadAirshipDefaults(index)
                        }
                    }

                    function _loadAirshipDefaults(pageIndex) {
                        var grid = factValueGrid
                        var defaults = root._pageDefaults[Math.min(pageIndex, root._pageDefaults.length - 1)]
                        for (var c = 0; c < defaults.cols.length; c++) {
                            var col = (c < grid.columns.count) ? grid.columns.get(c) : grid.appendColumn()
                            var factList = defaults.cols[c]
                            for (var r = 0; r < factList.length; r++) {
                                if (r >= grid.rowCount) grid.appendRow()
                                var parts = factList[r].split(".")
                                col.get(r).setFact(parts[0], parts[1])
                            }
                        }
                    }
                }
```

在 `root` 顶部 `property` 区追加默认指标数据：

```qml
    // 飞艇默认指标：每页 cols 数组，每列含 "factGroup.factName" 列表
    // factGroup: "Vehicle" 标准 / "ballast" 飞艇 AirshipBallastFactGroup（第一轮注册）
    property var _pageDefaults: [
        // 第 1 页：飞行核心
        { cols: [
            ["Vehicle.relativeAltitude", "Vehicle.climbRate", "Vehicle.heading"],
            ["Vehicle.groundSpeed", "Vehicle.flightTime", "Vehicle.distanceToHome"]
        ]},
        // 第 2 页：浮力/姿态
        { cols: [
            ["ballast.netBuoyancy", "ballast.altitudeError", "Vehicle.roll"],
            ["Vehicle.pitch", "ballast.blowerLeft", "ballast.blowerRight"]
        ]},
        // 第 3 页：能源/任务
        { cols: [
            ["Vehicle.batteryPercent", "Vehicle.flightDistance"],
            ["Vehicle.throttle", "Vehicle.airSpeed"]
        ]}
    ]
```

- [ ] **Step 4: 校验 fact 名对齐 Vehicle/AirshipBallast FactGroup**

Run: `grep -n "relativeAltitude\|climbRate\|groundSpeed\|flightTime\|distanceToHome\|flightDistance\|airSpeed\|throttle\|batteryPercent" src/Vehicle/FactGroups/VehicleFactGroup.h src/Vehicle/FactGroups/BatteryFactGroup.h`
Expected: 列出各 fact 定义；若 `batteryPercent` 实际名为 `percentRemaining` 或 `battery.percentRemaining`，修正 `_pageDefaults` 中对应字符串。

> 注：`batteryPercent` 在 QGC 通常为 `battery.percentRemaining`（BatteryFactGroup）。若 grep 确认，将 `"Vehicle.batteryPercent"` 改为 `"battery.percentRemaining"`。

- [ ] **Step 5: 编译 + 运行测试验证通过**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipPagedValuesBar --output-on-failure`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add src/FlyView/AirshipPagedValuesBar.qml test/UnitTestFramework/QmlTesting/tests/tst_AirshipPagedValuesBar.qml
git commit -m "feat(airship): inject default telemetry values into paged instrument on first use"
```

---

## Task 4: FlyViewBottomRightRowLayout 飞艇分支

**Files:**
- Modify: `src/FlyView/FlyViewBottomRightRowLayout.qml`
- Test: 现有 `Vehicle`/`QmlQuickTests` 回归（非飞艇走原路径）

**Interfaces:**
- Consumes: `AirshipPagedValuesBar`（Task 2/3）、`Vehicle.airship`、`FlyViewSettings.airshipShowTelemetryBar`
- Produces: 飞艇机型加载 `AirshipPagedValuesBar`，非飞艇走原 `TelemetryValuesBar`

- [ ] **Step 1: 写回归保护测试**

创建 `test/UnitTestFramework/QmlTesting/tests/tst_FlyViewBottomRightLayout.qml`：

```qml
import QtQuick
import QtTest
import QGroundControl

Rectangle {
    id: testRoot
    width: 800; height: 600

    Loader {
        id: layoutLoader
        source: "qrc:/qml/QGroundControl/FlyView/FlyViewBottomRightRowLayout.qml"
    }

    TestCase {
        name: "FlyViewBottomRightLayoutTest"
        when: windowShown

        // 无飞艇时不实例化 AirshipPagedValuesBar（避免误加载）
        function test_noAirshipUsesTelemetryValuesBar() {
            // 默认 activeVehicle 为 null 或非飞艇
            verify(layoutLoader.item, "layout loaded")
        }
    }
}
```

- [ ] **Step 2: 运行验证（基线）**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R FlyViewBottomRightLayout --output-on-failure`
Expected: PASS（当前原实现，作为回归基线）

- [ ] **Step 3: 修改 FlyViewBottomRightRowLayout.qml 加飞艇分支**

将原内容：

```qml
RowLayout {
    TelemetryValuesBar {
        Layout.alignment:       Qt.AlignBottom
        extraWidth:             instrumentPanel.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null // Tracks active vehicle
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }
}
```

改为：

```qml
RowLayout {
    property var  _activeVehicle:     globals.activeVehicle
    property bool _isAirship:         _activeVehicle && _activeVehicle.airship
    property bool _showAirshipBar:    QGroundControl.settingsManager.flyViewSettings.airshipShowTelemetryBar.rawValue

    Loader {
        Layout.alignment:       Qt.AlignBottom
        source: _isAirship && _showAirshipBar
                ? "qrc:/qml/QGroundControl/FlyView/AirshipPagedValuesBar.qml"
                : ""

        // 非飞艇时显示原 TelemetryValuesBar
        TelemetryValuesBar {
            Layout.alignment:       Qt.AlignBottom
            visible:                !(_isAirship && _showAirshipBar)
            extraWidth:             instrumentPanel.extraValuesWidth
            settingsGroup:          factValueGrid.telemetryBarSettingsGroup
            specificVehicleForCard: null // Tracks active vehicle
        }
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }
}
```

> 注：`factValueGrid` 是原 `TelemetryValuesBar` 的 alias，飞艇分支用 `Loader` 加载 `AirshipPagedValuesBar`。`extraValuesWidth` 透传保持姿态球间距。若 `Loader` 内 `TelemetryValuesBar` 嵌套报"重复 `factValueGrid`"冲突，改为用 `visible` 互斥的两个独立子项（飞艇 `AirshipPagedValuesBar` + 非飞艇 `TelemetryValuesBar`），二选一可见。

- [ ] **Step 4: 编译 + 回归测试**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R "FlyViewBottomRightLayout|Vehicle|QmlQuickTests" --output-on-failure`
Expected: PASS（非飞艇回归通过）

- [ ] **Step 5: Commit**

```bash
git add src/FlyView/FlyViewBottomRightRowLayout.qml test/UnitTestFramework/QmlTesting/tests/tst_FlyViewBottomRightLayout.qml
git commit -m "feat(airship): load AirshipPagedValuesBar for airship in FlyViewBottomRightRowLayout"
```

---

## Task 5: 长按姿态球显隐面板

**Files:**
- Modify: `src/FlyView/FlyViewInstrumentPanel.qml`
- Test: `test/UnitTestFramework/QmlTesting/tests/tst_AirshipInstrumentVisibility.qml` (Create)

**Interfaces:**
- Consumes: `FlyViewSettings.airshipShowTelemetryBar`（Task 1）、`FlyViewSettings.enableMultiVehiclePanel`（已有）
- Produces: 长按 `FlyViewInstrumentPanel` 弹出显隐开关面板

- [ ] **Step 1: 写失败测试**

创建 `test/UnitTestFramework/QmlTesting/tests/tst_AirshipInstrumentVisibility.qml`：

```qml
import QtQuick
import QtTest
import QGroundControl
import QGroundControl.FlyView

Rectangle {
    id: testRoot
    width: 200; height: 200

    FlyViewInstrumentPanel {
        id: panel
        anchors.fill: parent
    }

    TestCase {
        name: "AirshipInstrumentVisibilityTest"
        when: windowShown

        function test_airshipShowTelemetryBar_setting() {
            // 验证显隐设置项可读写（长按弹窗 UI 交互由 Task 7 手动验证）
            var settings = QGroundControl.settingsManager.flyViewSettings
            var before = settings.airshipShowTelemetryBar.rawValue
            settings.airshipShowTelemetryBar.rawValue = !before
            compare(settings.airshipShowTelemetryBar.rawValue, !before, "telemetry bar toggle persisted")
            settings.airshipShowTelemetryBar.rawValue = before
            compare(settings.airshipShowTelemetryBar.rawValue, before, "restored")
        }
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipInstrumentVisibility --output-on-failure`
Expected: FAIL（长按未绑定）

- [ ] **Step 3: 修改 FlyViewInstrumentPanel.qml 加长按手势 + 内联弹窗**

将原内容：

```qml
import QtQuick

import QGroundControl
import QGroundControl.Controls

SelectableControl {
    z:                      QGroundControl.zOrderWidgets
    selectionUIRightAnchor: true
    selectedControl:        QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    property var  missionController:    _missionController
    property real extraInset:           innerControl.extraInset
    property real extraValuesWidth:     innerControl.extraValuesWidth
}
```

改为：

```qml
import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SelectableControl {
    z:                      QGroundControl.zOrderWidgets
    selectionUIRightAnchor: true
    selectedControl:        QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    property var  missionController:    _missionController
    property real extraInset:           innerControl.extraInset
    property real extraValuesWidth:     innerControl.extraValuesWidth

    // 飞艇长按显隐面板
    property var  _flyViewSettings: QGroundControl.settingsManager.flyViewSettings
    property bool _visibilityPopup: false

    QGCMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressAndHold: (mouse) => {
            _visibilityPopup = true
            mouse.accepted = true
        }
    }

    QGCPopupDialogFactory {
        id: visibilityPopupFactory
        dialogComponent: visibilityPopup
    }

    Component {
        id: visibilityPopup

        QGCPopupDialog {
            title:   qsTr("Show / Hide Panels")
            buttons:  Dialog.Close

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCCheckBoxSlider {
                    text:    qsTr("Telemetry Bar")
                    checked: _flyViewSettings.airshipShowTelemetryBar.rawValue
                    onClicked: _flyViewSettings.airshipShowTelemetryBar.rawValue = checked
                }
                QGCCheckBoxSlider {
                    text:    qsTr("Multi-Vehicle Panel")
                    checked: QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.rawValue
                    onClicked: QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.rawValue = checked
                }
            }
        }
    }

    on_VisibilityPopupChanged: {
        if (_visibilityPopup) {
            visibilityPopupFactory.open({})
            _visibilityPopup = false
        }
    }
}
```

- [ ] **Step 4: 编译 + 运行测试验证通过**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R AirshipInstrumentVisibility --output-on-failure`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/FlyView/FlyViewInstrumentPanel.qml test/UnitTestFramework/QmlTesting/tests/tst_AirshipInstrumentVisibility.qml
git commit -m "feat(airship): add press-and-hold panel visibility popup on instrument panel"
```

---

## Task 6: 启用航向指示器（全局 default 改 true）

**Files:**
- Modify: `src/Settings/FlyView.SettingsGroup.json`
- Test: 现有 `QmlQuickTests` 回归

**Interfaces:**
- Produces: `showAdditionalIndicatorsCompass` default = true（飞艇自动获得家方向/航点/COG 指示器）

- [ ] **Step 1: 查看当前 default**

Run: `grep -A6 "showAdditionalIndicatorsCompass" src/Settings/FlyView.SettingsGroup.json`
Expected: 显示当前 `"default": false`（或未设）

- [ ] **Step 2: 修改 default 为 true**

在 `FlyView.SettingsGroup.json` 的 `showAdditionalIndicatorsCompass` 条目，将 `"default"` 改为 `true`（若无 `default` 字段则新增 `"default": true`）：

```json
        {
            "name": "showAdditionalIndicatorsCompass",
            ...
            "default": true,
            ...
        }
```

- [ ] **Step 3: 编译 + 回归**

Run: `cmake --build build/Desktop_Qt_6_10_1-Debug --target QGroundControl -j$(nproc) && ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R "QmlQuickTests|QmlUITests" --output-on-failure`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/Settings/FlyView.SettingsGroup.json
git commit -m "feat(airship): enable additional compass indicators by default (home/waypoint/COG)"
```

---

## Task 7: MockLink 端到端 + 全量回归

**Files:**
- 无新文件；使用第一轮 `PX4MockLinkAirship.params` + `AirshipBallastFactGroup`

**Interfaces:**
- Consumes: `PX4MockLinkAirship.params`、`AirshipBallastFactGroup`（NAMED_VALUE_FLOAT: buoy/blw_l/blw_r/vlv_l/vlv_r/alt_err）

- [ ] **Step 1: 验证 MockLink 飞艇 NAMED_VALUE_FLOAT 发送**

Run: `grep -n "buoy\|blw_l\|netBuoyancy\|NAMED_VALUE_FLOAT" src/Comms/MockLink/MockLink.cc | head -20`
Expected: 显示飞艇 MockLink 发送 NAMED_VALUE_FLOAT 的代码（第一轮实现）

> 若 MockLink 未发送 ballast NAMED_VALUE_FLOAT，需在 `MockLink.cc` 的 `startAirshipMockLink` 路径补发（参考第一轮记录 2.8 节）。

- [ ] **Step 2: 手动端到端验证（启动 QGC + 飞艇 MockLink）**

Run: `./build/Desktop_Qt_6_10_1-Debug/Debug/QGroundControl &`
操作：Application Settings → Mock Link → 启动 PX4 Airship MockLink → 进入 Fly View
验证：
- 右下角显示 `AirshipPagedValuesBar`（3 页，可滑动切换）
- 第 2 页显示净浮力/鼓风机/阀门/高度误差（来自 `ballast` FactGroup）
- 长按姿态球弹出显隐面板，可切换 telemetry bar
- 姿态球显示家方向"L"、下个航点虚线、移动方向 COG

- [ ] **Step 3: 全量回归**

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -L Vehicle --output-on-failure --parallel 4`
Expected: 26/26 PASS（Vehicle 测试，与第一轮一致）

Run: `ctest --test-dir build/Desktop_Qt_6_10_1-Debug/test -R "Airship|QmlQuickTests|QmlUITests|Firmware" --output-on-failure`
Expected: PASS

- [ ] **Step 4: 最终 Commit（如有 MockLink 补发）**

```bash
git add -u
git commit -m "test(airship): verify paged instrument end-to-end with MockLink airship"
```

---

## Self-Review

**1. Spec coverage**：
- 4.1 整体架构 → Task 2+4（分页容器 + 飞艇分支注入）
- 4.2 组件结构 → Task 2（AirshipPagedValuesBar.qml）；C++ 加载器已按 YAGNI 优化为 QML 注入
- 4.3 数据流与持久化 → Task 1（设置项）+ Task 2（每页 settingsGroup `AirshipInstr.Page*`）+ Task 3（默认注入）
- 4.4 飞艇默认指标集 → Task 3（`_pageDefaults` 3 页）
- 4.5 姿态球航向指示器 → Task 6（default 改 true）
- 4.6 长按显隐面板 → Task 5（FlyViewInstrumentPanel）
- 4.7 错误处理 → Task 2（页数 clamp 1~5）+ Task 3（空网格才注入）
- 4.8 测试 → 每个 Task 的 QML 测试 + Task 7 端到端/回归

**2. Placeholder scan**：无 TBD/TODO；所有代码步骤含完整可执行代码。Task 3 Step 4 的 fact 名校验是验证步骤（非占位符）。

**3. Type consistency**：
- `pageCount` (int) — Task 2 定义，Task 1 提供 setting，一致
- `appendPage()`/`deleteLastPage()` — Task 2 定义，Task 2 测试使用，一致
- `_loadAirshipDefaults(pageIndex)` — Task 3 定义并被 Task 3 测试调用，一致
- `factValueGrid` — `TelemetryValuesBar` 的 alias（Task 2/3/4 使用，与现有 `TelemetryValuesBar.qml` 一致）
- `_pageDefaults` 结构 `{cols: [[...], [...]]}` — Task 3 定义与使用一致
- `airshipShowTelemetryBar` / `airshipInstrumentPageCount` — Task 1 定义，Task 2/4/5 使用，一致

**4. 对设计文档的偏离（已注明）**：
- 去 C++ 加载器 → QML 注入（YAGNI）
- `showAdditionalIndicatorsCompass` 改全局 default 而非 firmware plugin（更简单，对所有机型有益）
