import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

// 飞艇专用分页数据仪表盘。
//
// 三条主题页（飞行核心 / 浮力 / 能源）在底部并排横向展示（不重叠），
// 每页是 TelemetryValuesBar 的一个窄单列（默认 3 值，见
// QGCCorePlugin::_createAirshipPagedDefaultSettings），各自独立 settingsGroup 持久化。
// 长按/右键弹出显隐面板，可勾选只显示需要的模块（FlyViewSettings.airshipShowPage*）。
// 注意: 本组件由 Loader 加载，Loader 尺寸取 implicitWidth/implicitHeight，必须提供。
Item {
    id: root

    property bool settingsUnlocked: false
    property real _margins: ScreenTools.defaultFontPixelWidth / 2

    // 三个页面的显隐开关由解锁弹窗控制，默认全开
    readonly property var _flyViewSettings: QGroundControl.settingsManager.flyViewSettings
    readonly property bool _showFlightCore: _flyViewSettings.airshipShowPageFlightCore.rawValue
    readonly property bool _showBuoyancy:   _flyViewSettings.airshipShowPageBuoyancy.rawValue
    readonly property bool _showEnergy:     _flyViewSettings.airshipShowPageEnergy.rawValue
    // 至少保持一页可见，避免面板为空
    readonly property bool _showAny:        _showFlightCore || _showBuoyancy || _showEnergy

    implicitWidth:  barRow.implicitWidth + (_margins * 2)
    implicitHeight: barRow.implicitHeight + (_margins * 2)

    Rectangle {
        anchors.fill: parent
        color: qgcPal.window
        opacity: 0.75
        radius: ScreenTools.defaultFontPixelWidth / 2
    }

    QGCPalette { id: qgcPal }

    RowLayout {
        id:                 barRow
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.margins:    _margins
        // 间距拉大让三页各自的圆角背景之间露出缝隙，视觉上是三个独立面板
        spacing:            ScreenTools.defaultFontPixelWidth * 1.5

        // 三个主题页显式展开（不用 Repeater+modelData：数组模型在自定义组件
        // delegate 中 modelData 注入不可靠，会 ReferenceError 导致整条不显示）
        TelemetryValuesBar {
            id:                 pageFlightCore
            Layout.alignment:   Qt.AlignBottom
            visible:            root._showAny && root._showFlightCore
            settingsGroup:      "AirshipInstr.Page0"
            specificVehicleForCard: null
            extraWidth:         0
            factValueGrid.maxColumns:     1
            factValueGrid.maxRows:        3
            factValueGrid.emptyNewValues: true
            property bool _pageUnlocked: root.settingsUnlocked

            Binding {
                target: pageFlightCore.factValueGrid
                property: "settingsUnlocked"
                value: pageFlightCore._pageUnlocked
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        TelemetryValuesBar {
            id:                 pageBuoyancy
            Layout.alignment:   Qt.AlignBottom
            visible:            root._showAny && root._showBuoyancy
            settingsGroup:      "AirshipInstr.Page1"
            specificVehicleForCard: null
            extraWidth:         0
            factValueGrid.maxColumns:     1
            factValueGrid.maxRows:        3
            factValueGrid.emptyNewValues: true
            property bool _pageUnlocked: root.settingsUnlocked

            Binding {
                target: pageBuoyancy.factValueGrid
                property: "settingsUnlocked"
                value: pageBuoyancy._pageUnlocked
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        TelemetryValuesBar {
            id:                 pageEnergy
            Layout.alignment:   Qt.AlignBottom
            visible:            root._showAny && root._showEnergy
            settingsGroup:      "AirshipInstr.Page2"
            specificVehicleForCard: null
            extraWidth:         0
            factValueGrid.maxColumns:     1
            factValueGrid.maxRows:        3
            factValueGrid.emptyNewValues: true
            property bool _pageUnlocked: root.settingsUnlocked

            Binding {
                target: pageEnergy.factValueGrid
                property: "settingsUnlocked"
                value: pageEnergy._pageUnlocked
                restoreMode: Binding.RestoreBindingOrValue
            }
        }

        // 解锁态底部行：页面显隐开关 + 收起编辑锁
        QGCButton {
            id:                 pagesButton
            Layout.alignment:   Qt.AlignBottom
            visible:            root.settingsUnlocked
            text:               qsTr("Modules")
            onClicked:          pagesPopupFactory.open({})
        }

        Item { Layout.fillWidth: true }

        QGCColoredImage {
            Layout.alignment:   Qt.AlignBottom
            source:             "qrc:/InstrumentValueIcons/lock-open.svg"
            visible:            root.settingsUnlocked
            mipmap:             true
            width:              ScreenTools.minTouchPixels * 0.5
            height:             width
            sourceSize.width:   width
            fillMode:           Image.PreserveAspectFit
            color:              qgcPal.text

            QGCMouseArea {
                anchors.fill: parent
                onClicked:    root.settingsUnlocked = false
            }
        }
    }

    QGCPopupDialogFactory {
        id:             pagesPopupFactory
        dialogComponent: pagesPopup
    }

    Component {
        id: pagesPopup

        QGCPopupDialog {
            id:      pagesPopupDialog
            title:   qsTr("Show Modules")
            buttons: Dialog.Close

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCCheckBoxSlider {
                    text:     qsTr("Flight Core")
                    checked:   root._flyViewSettings.airshipShowPageFlightCore.rawValue
                    onClicked: root._flyViewSettings.airshipShowPageFlightCore.rawValue = checked
                }

                QGCCheckBoxSlider {
                    text:     qsTr("Buoyancy / Attitude")
                    checked:   root._flyViewSettings.airshipShowPageBuoyancy.rawValue
                    onClicked: root._flyViewSettings.airshipShowPageBuoyancy.rawValue = checked
                }

                QGCCheckBoxSlider {
                    text:     qsTr("Energy / Mission")
                    checked:   root._flyViewSettings.airshipShowPageEnergy.rawValue
                    onClicked: root._flyViewSettings.airshipShowPageEnergy.rawValue = checked
                }
            }
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