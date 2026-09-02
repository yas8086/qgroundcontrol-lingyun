import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// 飞艇浮力控制 HUD 面板（PX4 五字段契约，03_interfaces.md §5）
// 净浮力 / 单囊质量 / 风机占空比 / 阀门状态 / 高度误差
// 通过 vehicle.ballast FactGroup 获取数据（NAMED_VALUE_FLOAT 消息）
Rectangle {
    id:             root
    width:          _panelWidth
    // ColumnLayout 作为普通子项时 height 默认为 0，必须用 implicitHeight（由内容计算）
    height:         _column.implicitHeight + (_margins * 2)
    color:          qgcPal.window
    radius:         ScreenTools.defaultFontPixelHeight * 0.25
    opacity:        0.85
    // 注意: QML 里 Vehicle 没有 vehicleType 属性（那是 C++ 方法），必须用 airship bool 属性判断
    visible:        _activeVehicle && _activeVehicle.airship

    property var    _activeVehicle:     globals.activeVehicle
    property real   _margins:           ScreenTools.defaultFontPixelWidth * 0.5
    property real   _panelWidth:        ScreenTools.defaultFontPixelWidth * 28
    property real   _barHeight:         ScreenTools.defaultFontPixelHeight * 0.6
    property real   _barWidth:          _panelWidth - _margins * 4
    property var    _ballast:           _activeVehicle ? _activeVehicle.ballast : null
    // 当前飞行模式（起飞/降落推进电机关闭指示）
    // 注意：Failsafe 为飞控内部态不反映到 nav_state（04_modes.md §3.3），此处不可检测
    property string _flightMode:        _activeVehicle ? _activeVehicle.flightMode : ""
    property bool   _isTakeoff:         _flightMode === "Takeoff"
    property bool   _isLand:            _flightMode === "Land"
    // 起飞/降落模式推进电机关闭（nav_state 硬开关，04_modes.md §5）
    property bool   _propulsionOff:     _isTakeoff || _isLand
    // 单囊最大空气质量（BALLOON_M_MAX 代码默认 128.5kg，02_parameters.md §9）
    property real   _ballastMassMax:    128.5
    // 超压告警近似推断：b_mass > M_MAX*95%（06_qgc_dev_guide.md §2.2）
    property bool   _overpressure:      _ballast ? _ballast.ballastMass.value > _ballastMassMax * 0.95 : false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    ColumnLayout {
        id:                 _column
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.margins:    _margins
        spacing:            _margins

        // 标题 + 浮力平衡/超压状态指示器
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text: qsTr("Ballast Control")
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Item { Layout.fillWidth: true }

            // 超压告警（b_mass > M_MAX*95% 近似推断）
            Rectangle {
                visible: _overpressure
                color: "#F44336"
                radius: ScreenTools.defaultFontPixelHeight * 0.2
                implicitWidth: _overpressureLabel.implicitWidth + _margins * 2
                implicitHeight: _overpressureLabel.implicitHeight + _margins * 0.5

                QGCLabel {
                    id: _overpressureLabel
                    anchors.centerIn: parent
                    text: qsTr("超压")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }

            // 浮力平衡状态指示器（|净浮力| < 0.5N 时显示）
            Rectangle {
                visible: _ballast && Math.abs(_ballast.netBuoyancy.value) < 0.5
                color: "#4CAF50"
                radius: ScreenTools.defaultFontPixelHeight * 0.2
                implicitWidth: _statusLabel.implicitWidth + _margins * 2
                implicitHeight: _statusLabel.implicitHeight + _margins * 0.5

                QGCLabel {
                    id: _statusLabel
                    anchors.centerIn: parent
                    text: qsTr("浮力平衡")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        // 飞行模式状态指示器（起飞/降落/推进电机关闭）
        // 注：起飞完成自动切 Loiter、Land 到 3m 自动 DISARM 属正常行为（04_modes.md §4）
        Rectangle {
            Layout.fillWidth: true
            visible: _isTakeoff || _isLand
            color: _isTakeoff ? "#2196F3" : "#FF9800"
            radius: ScreenTools.defaultFontPixelHeight * 0.15
            implicitHeight: _modeStatusLayout.implicitHeight + _margins

            ColumnLayout {
                id: _modeStatusLayout
                anchors.fill: parent
                anchors.margins: _margins * 0.5
                spacing: 0

                // 起飞状态
                QGCLabel {
                    visible: _isTakeoff
                    text: qsTr("▲ 起飞中")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                // 降落状态
                QGCLabel {
                    visible: _isLand
                    text: qsTr("▼ 降落中")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                // 推进电机关闭指示（起飞/降落模式）
                QGCLabel {
                    visible: _propulsionOff
                    text: qsTr("推进电机: OFF")
                    color: "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        // 净浮力
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text: qsTr("Net Buoyancy")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Item { Layout.fillWidth: true }
            QGCLabel {
                text: _ballast ? _ballast.netBuoyancy.value.toFixed(1) + " N" : "—"
                font.pointSize: ScreenTools.smallFontPointSize
                color: _ballast ? (_ballast.netBuoyancy.value > 0.5 ? qgcPal.colorOrange
                                : _ballast.netBuoyancy.value < -0.5 ? qgcPal.colorRed
                                : qgcPal.text) : qgcPal.text
            }
        }

        // 单囊空气质量（0 ~ BALLOON_M_MAX）
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("Ballast Mass")
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text: _ballast ? _ballast.ballastMass.value.toFixed(1) + " kg" : "—"
                    font.pointSize: ScreenTools.smallFontPointSize
                    color: _overpressure ? qgcPal.colorRed : qgcPal.text
                }
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: _ballastMassMax
                value: _ballast ? _ballast.ballastMass.value : 0
                height: _barHeight
            }
        }

        // 风机占空比（0-255）
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("Blower")
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text: _ballast ? (_ballast.blowerDuty.value / 255 * 100).toFixed(0) + "%" : "—"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 255
                value: _ballast ? _ballast.blowerDuty.value : 0
                height: _barHeight
            }
        }

        // 阀门状态（0=关 / 255=开，常闭阀）
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text: qsTr("Valve")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Item { Layout.fillWidth: true }
            // 阀门状态灯
            Rectangle {
                width: ScreenTools.defaultFontPixelHeight * 0.5
                height: width
                radius: width / 2
                color: (_ballast && _ballast.valveState.value > 127) ? "#4CAF50" : qgcPal.button
                border.color: qgcPal.text
                border.width: 1
            }
            QGCLabel {
                text: (_ballast && _ballast.valveState.value > 127) ? qsTr("Open") : qsTr("Closed")
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        // 高度误差
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text: qsTr("Alt Error")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Item { Layout.fillWidth: true }
            QGCLabel {
                text: _ballast ? _ballast.altitudeError.value.toFixed(1) + " m" : "—"
                font.pointSize: ScreenTools.smallFontPointSize
                color: _ballast ? (Math.abs(_ballast.altitudeError.value) > 2.0 ? qgcPal.colorOrange : qgcPal.text) : qgcPal.text
            }
        }
    }
}
