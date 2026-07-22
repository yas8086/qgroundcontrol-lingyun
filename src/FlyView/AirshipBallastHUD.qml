import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// 飞艇浮力控制 HUD 面板
// 显示净浮力、鼓风机/阀门输出、高度误差
// 通过 vehicle.ballast FactGroup 获取数据（NAMED_VALUE_FLOAT 消息）
Rectangle {
    id:             root
    width:          _panelWidth
    height:         _column.height + (_margins * 2)
    color:          qgcPal.window
    radius:         ScreenTools.defaultFontPixelHeight * 0.25
    opacity:        0.85
    visible:        _activeVehicle && _activeVehicle.vehicleType === 7  // MAV_TYPE_AIRSHIP

    property var    _activeVehicle:     globals.activeVehicle
    property real   _margins:           ScreenTools.defaultFontPixelWidth * 0.5
    property real   _panelWidth:        ScreenTools.defaultFontPixelWidth * 28
    property real   _barHeight:         ScreenTools.defaultFontPixelHeight * 0.6
    property real   _barWidth:          _panelWidth - _margins * 4
    property var    _ballast:           _activeVehicle ? _activeVehicle.ballast : null
    // 当前飞行模式（用于起飞/降落/Failsafe 状态指示）
    property string _flightMode:        _activeVehicle ? _activeVehicle.flightMode : ""
    property bool   _isTakeoff:         _flightMode === "Takeoff"
    property bool   _isLand:            _flightMode === "Land"
    property bool   _isFailsafe:        _flightMode === "Failsafe"
    // 起飞/降落模式推进电机关闭
    property bool   _propulsionOff:     _isTakeoff || _isLand

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // 数据流调试日志
    Component.onCompleted: console.log("AirshipBallastHUD: initialized, vehicleType=", _activeVehicle ? _activeVehicle.vehicleType : "null")
    onVisibleChanged: console.log("AirshipBallastHUD: visible =", visible)

    // 数据流调试定时器：每秒打印一次 Fact 值
    Timer {
        interval: 1000
        running: visible && _ballast
        repeat: true
        onTriggered: {
            if (_ballast) {
                console.log("AirshipBallastHUD: buoy=", _ballast.netBuoyancy.value,
                            "blw_l=", _ballast.blowerLeft.value,
                            "blw_r=", _ballast.blowerRight.value,
                            "vlv_l=", _ballast.valveLeft.value,
                            "vlv_r=", _ballast.valveRight.value,
                            "alt_err=", _ballast.altitudeError.value)
            }
        }
    }

    ColumnLayout {
        id:                 _column
        anchors.margins:    _margins
        anchors.fill:       parent
        spacing:            _margins

        // 标题 + 浮力平衡状态指示器
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text: qsTr("Ballast Control")
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Item { Layout.fillWidth: true }

            // 浮力平衡状态指示器（|净浮力| < 0.5N 时显示）
            Rectangle {
                visible: _ballast && Math.abs(_ballast.netBuoyancy.value) < 0.5
                color: "#4CAF50"  // 绿色
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

        // 飞行模式状态指示器（起飞/降落/Failsafe/推进电机关闭）
        Rectangle {
            Layout.fillWidth: true
            visible: _isTakeoff || _isLand || _isFailsafe || _propulsionOff
            color: _isFailsafe ? "#F44336" : (_isTakeoff ? "#2196F3" : (_isLand ? "#FF9800" : qgcPal.windowShade))
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
                // Failsafe 状态
                QGCLabel {
                    visible: _isFailsafe
                    text: qsTr("⚠ Failsafe")
                    color: "white"
                    font.bold: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                // 推进电机关闭指示（起飞/降落模式）
                QGCLabel {
                    visible: _propulsionOff
                    text: qsTr("推进电机: OFF")
                    color: _isFailsafe ? "white" : qgcPal.text
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
                color: _ballast ? (_ballast.netBuoyancy.value > 0.5 ? qgcPal.warning
                                : _ballast.netBuoyancy.value < -0.5 ? qgcPal.danger
                                : qgcPal.text) : qgcPal.text
            }
        }

        // 左鼓风机
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QGCLabel {
                text: qsTr("Blower L: ") + (_ballast ? (_ballast.blowerLeft.value * 100).toFixed(0) + "%" : "—")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 1
                value: _ballast ? _ballast.blowerLeft.value : 0
                height: _barHeight
            }
        }

        // 右鼓风机
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QGCLabel {
                text: qsTr("Blower R: ") + (_ballast ? (_ballast.blowerRight.value * 100).toFixed(0) + "%" : "—")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 1
                value: _ballast ? _ballast.blowerRight.value : 0
                height: _barHeight
            }
        }

        // 左阀门
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QGCLabel {
                text: qsTr("Valve L: ") + (_ballast ? (_ballast.valveLeft.value * 100).toFixed(0) + "%" : "—")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 1
                value: _ballast ? _ballast.valveLeft.value : 0
                height: _barHeight
            }
        }

        // 右阀门
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QGCLabel {
                text: qsTr("Valve R: ") + (_ballast ? (_ballast.valveRight.value * 100).toFixed(0) + "%" : "—")
                font.pointSize: ScreenTools.smallFontPointSize
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 1
                value: _ballast ? _ballast.valveRight.value : 0
                height: _barHeight
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
                color: _ballast ? (Math.abs(_ballast.altitudeError.value) > 2.0 ? qgcPal.warning : qgcPal.text) : qgcPal.text
            }
        }
    }
}
