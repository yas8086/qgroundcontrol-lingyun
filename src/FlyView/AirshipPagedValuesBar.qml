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

    // 飞艇默认指标：每页 cols 数组，每列含 "factGroup.factName" 列表
    // factGroup: "Vehicle" 标准 / "ballast" 飞艇 AirshipBallastFactGroup（注册名 "ballast"）
    // fact 名按 VehicleFactGroup.h/AirshipBallastFactGroup.h 实际名（altitudeRelative/throttlePct）
    property var _pageDefaults: [
        // 第 1 页：飞行核心
        { cols: [
            ["Vehicle.altitudeRelative", "Vehicle.climbRate", "Vehicle.heading"],
            ["Vehicle.groundSpeed", "Vehicle.flightTime", "Vehicle.distanceToHome"]
        ]},
        // 第 2 页：浮力/姿态
        { cols: [
            ["ballast.netBuoyancy", "ballast.altitudeError", "Vehicle.roll"],
            ["Vehicle.pitch", "ballast.blowerLeft", "ballast.blowerRight"]
        ]},
        // 第 3 页：能源/任务（altitudeAMSL 替代 battery：QGC 网格 setFact 不支持 battery list model）
        { cols: [
            ["Vehicle.altitudeAMSL", "Vehicle.flightDistance"],
            ["Vehicle.throttlePct", "Vehicle.airSpeed"]
        ]}
    ]

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

        QGCSwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: root.pageCount

                TelemetryValuesBar {
                    id: pageBar
                    settingsGroup: "AirshipInstr.Page" + index
                    specificVehicleForCard: null
                    extraWidth: 0
                    property bool _pageUnlocked: root.settingsUnlocked

                    // I-1 fix: 用 Binding{} 替代直接属性绑定，避免被 TelemetryValuesBar.qml
                    // 内部 onClicked: factValueGrid.settingsUnlocked = false 赋值断开。
                    // restoreMode=RestoreBindingOrValue 让 Binding 释放后保留内部赋值。
                    Binding {
                        target: pageBar.factValueGrid
                        property: "settingsUnlocked"
                        value: pageBar._pageUnlocked
                        restoreMode: Binding.RestoreBindingOrValue
                    }

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
            }
        }

        QGCPageIndicator {
            count: swipeView.count
            currentIndex: swipeView.currentIndex
            Layout.alignment: Qt.AlignHCenter
        }
    }

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
