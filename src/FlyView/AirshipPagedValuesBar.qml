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
