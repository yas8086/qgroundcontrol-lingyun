import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// 飞艇浮力控制 HUD 面板（PX4 十五字段契约，03_interfaces.md §5 + 四囊压差/风机/阀门透出）
// 汇总区：净浮力 / 囊质量 / 高度误差；四囊独立卡片：压差 + 风机占空比 + 阀门开关（2x2 按物理位置）
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
    property real   _panelWidth:        ScreenTools.defaultFontPixelWidth * 56
    property real   _barHeight:         ScreenTools.defaultFontPixelHeight * 0.7
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
    // 四囊压差（kPa）：LoRa传感器x4 → 树莓派 → uXRCE-DDS → 飞控透出 bal_p0~p3
    // 压差数据未上线时 Fact 为 NaN（连接前/传感器从未有效）
    property var    _pressureFacts:     _ballast ? [_ballast.bladderPressure0, _ballast.bladderPressure1,
                                                     _ballast.bladderPressure2, _ballast.bladderPressure3] : []
    property bool   _pressureValid:     _ballast ? !isNaN(_ballast.bladderPressure0.value)
                                                 || !isNaN(_ballast.bladderPressure1.value)
                                                 || !isNaN(_ballast.bladderPressure2.value)
                                                 || !isNaN(_ballast.bladderPressure3.value) : false
    // 超压告警：优先真实压差（任一囊 > 4.75 kPa，验证指南 §5.2）；
    // 压差数据全无效时回退 b_mass > M_MAX*95% 近似推断（06_qgc_dev_guide.md §2.2）
    property bool   _overpressure:      _pressureValid ? _anyPressureOverLimit()
                                                       : (_ballast ? _ballast.ballastMass.value > _ballastMassMax * 0.95 : false)
    // 四囊不平衡（全部有效且 max-min > 0.5 kPa，飞控同步告警 bladder imbalance）
    property bool   _bladderImbalance:  _ballast && _allPressuresValid() ? _pressureSpread() > 0.5 : false

    function _anyPressureOverLimit() {
        for (var i = 0; i < _pressureFacts.length; i++) {
            var v = _pressureFacts[i].value
            if (!isNaN(v) && v > 4.75) return true
        }
        return false
    }
    function _allPressuresValid() {
        for (var i = 0; i < _pressureFacts.length; i++) {
            if (isNaN(_pressureFacts[i].value)) return false
        }
        return true
    }
    function _pressureSpread() {
        var mn = Infinity, mx = -Infinity
        for (var i = 0; i < _pressureFacts.length; i++) {
            var v = _pressureFacts[i].value
            mn = Math.min(mn, v); mx = Math.max(mx, v)
        }
        return mx - mn
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    // 单囊独立卡片：压差 + 风机占空比 + 阀门开关（数据无效 NaN 时显示 "—"）
    // 文件内 inline 组件（非 Loader/Repeater，避免动态作用域注入失效）
    // 统一样式进度条: 暗色轨道 + 白色进度(无数据时值为0, 白条为空、灰色轨道占满, 视觉为"空槽"状态)
    component AirshipBar: ProgressBar {
        id:         _bar
        height:     _barHeight
        background: Rectangle {
            implicitWidth:  _bar.width
            implicitHeight: _barHeight
            color:          "#40FFFFFF"
            radius:         2
        }
        contentItem: Item {
            implicitHeight: _barHeight
            Rectangle {
                width:  _bar.visualPosition * _bar.availableWidth
                height: parent.height
                color:  "#FFFFFF"
                radius: 2
            }
        }
    }

    component BladderCard: Rectangle {
        id:                 card
        property string     cardTitle:     ""
        property int        bladderIndex:  0       // 囊序号 0~3，用于标注协议字段名 bal_pN/blowerN/valveN
        property var        pressureFact: null
        property var        blowerFact:   null
        property var        valveFact:    null
        property bool       pressureHigh: pressureFact && !isNaN(pressureFact.value) && pressureFact.value > 4.75

        Layout.fillWidth:   true
        implicitHeight:     cardColumn.implicitHeight + (_margins * 2)
        color:              qgcPal.windowShade
        radius:             ScreenTools.defaultFontPixelHeight * 0.2

        ColumnLayout {
            id:             cardColumn
            anchors.top:        parent.top
            anchors.left:      parent.left
            anchors.right:     parent.right
            anchors.margins:   _margins
            spacing:        _margins * 0.5

            // 囊名称（按物理位置）
            QGCLabel {
                text:               card.cardTitle
                font.bold:          true
                font.pointSize:     ScreenTools.largeFontPointSize
            }

            // 压差（kPa，0~5 正常区间，>4.75 超压数值变红）
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("压差") }
                QGCLabel {
                    text:           "(bal_p" + card.bladderIndex + ")"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:               card.pressureFact && !isNaN(card.pressureFact.value) ? card.pressureFact.value.toFixed(2) + " kPa" : "—"
                    font.pointSize:     ScreenTools.largeFontPointSize
                    color:              card.pressureHigh ? qgcPal.colorRed : qgcPal.text
                }
            }
            AirshipBar {
                Layout.fillWidth: true
                from:   0
                to:     5
                value:  card.pressureFact && !isNaN(card.pressureFact.value) ? card.pressureFact.value : 0
            }

            // 风机占空比（0-100%，0=停）
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("风机") }
                QGCLabel {
                    text:           "(blower" + card.bladderIndex + ")"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           card.blowerFact && !isNaN(card.blowerFact.value) ? card.blowerFact.value.toFixed(0) + " %" : "—"
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }
            AirshipBar {
                Layout.fillWidth: true
                from:   0
                to:     100
                value:  card.blowerFact && !isNaN(card.blowerFact.value) ? card.blowerFact.value : 0
            }

            // 阀门（0=关 / 100=开，常闭阀）
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("阀门") }
                QGCLabel {
                    text:           "(valve" + card.bladderIndex + ")"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width:              ScreenTools.defaultFontPixelHeight * 0.5
                    height:             width
                    radius:             width / 2
                    color:              card.valveFact && !isNaN(card.valveFact.value) && card.valveFact.value > 50 ? "#4CAF50" : qgcPal.button
                    border.color:       qgcPal.text
                    border.width:       1
                }
                QGCLabel {
                    text:           card.valveFact && !isNaN(card.valveFact.value) ? (card.valveFact.value > 50 ? qsTr("开") : qsTr("关")) : "—"
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }
        }
    }

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
                text:               qsTr("气囊浮力监控")
                font.bold:          true
                font.pointSize:     ScreenTools.largeFontPointSize
            }
            Item { Layout.fillWidth: true }

            // 超压告警（任一囊压差 > 4.75 kPa 或 b_mass > M_MAX*95% 近似推断）
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
                }
                // 降落状态
                QGCLabel {
                    visible: _isLand
                    text: qsTr("▼ 降落中")
                    color: "white"
                    font.bold: true
                }
                // 推进电机关闭指示（起飞/降落模式）
                QGCLabel {
                    visible: _propulsionOff
                    text: qsTr("推进电机: OFF")
                    color: "white"
                }
            }
        }

        // 汇总：净浮力 / 高度误差（两列）
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins * 2

            RowLayout {
                Layout.fillWidth: true
                spacing: _margins

                QGCLabel {
                    text: qsTr("净浮力")
                }
                QGCLabel {
                    text:           "(buoy)"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           _ballast ? _ballast.netBuoyancy.value.toFixed(1) + " N" : "—"
                    font.pointSize: ScreenTools.largeFontPointSize
                    color: _ballast ? (_ballast.netBuoyancy.value > 0.5 ? qgcPal.colorOrange
                                    : _ballast.netBuoyancy.value < -0.5 ? qgcPal.colorRed
                                    : qgcPal.text) : qgcPal.text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: _margins

                QGCLabel {
                    text: qsTr("高度误差")
                }
                QGCLabel {
                    text:           "(alt_err)"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           _ballast ? _ballast.altitudeError.value.toFixed(1) + " m" : "—"
                    font.pointSize: ScreenTools.largeFontPointSize
                    color: _ballast ? (Math.abs(_ballast.altitudeError.value) > 2.0 ? qgcPal.colorOrange : qgcPal.text) : qgcPal.text
                }
            }
        }

        // 囊质量（0 ~ BALLOON_M_MAX）
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("囊质量")
                }
                QGCLabel {
                    text:           "(b_mass)"
                    font.pointSize: ScreenTools.smallFontPointSize
                    opacity:        0.6
                }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    text:           _ballast ? _ballast.ballastMass.value.toFixed(1) + " kg" : "—"
                    font.pointSize: ScreenTools.largeFontPointSize
                    color: _overpressure ? qgcPal.colorRed : qgcPal.text
                }
            }
            AirshipBar {
                Layout.fillWidth: true
                from: 0; to: _ballastMassMax
                value: _ballast && !isNaN(_ballast.ballastMass.value) ? _ballast.ballastMass.value : 0
            }
        }

        // 四囊独立状态区标题（2x2 按物理位置排布：上行左副/左主，下行右主/右副）
        RowLayout {
            Layout.fillWidth: true
            spacing: _margins

            QGCLabel {
                text:               qsTr("四囊状态")
                font.bold:          true
                font.pointSize:     ScreenTools.largeFontPointSize
            }
            Item { Layout.fillWidth: true }
            // 四囊不平衡指示（max-min > 0.5kPa，飞控同步输出 bladder imbalance 告警）
            Rectangle {
                visible: root._bladderImbalance
                color: "#FF9800"
                radius: ScreenTools.defaultFontPixelHeight * 0.2
                implicitWidth: _imbalanceLabel.implicitWidth + _margins * 2
                implicitHeight: _imbalanceLabel.implicitHeight + _margins * 0.5
                QGCLabel {
                    id: _imbalanceLabel
                    anchors.centerIn: parent
                    text: qsTr("不平衡")
                    color: "white"
                    font.bold: true
                }
            }
        }

        // 四囊独立卡片（压差 + 风机 + 阀门）
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: _margins
            rowSpacing: _margins

            BladderCard {
                cardTitle:     qsTr("左副囊")
                bladderIndex:  0
                pressureFact: root._ballast ? root._ballast.bladderPressure0 : null
                blowerFact:   root._ballast ? root._ballast.blower0 : null
                valveFact:    root._ballast ? root._ballast.valve0 : null
            }

            BladderCard {
                cardTitle:     qsTr("左主囊")
                bladderIndex:  1
                pressureFact: root._ballast ? root._ballast.bladderPressure1 : null
                blowerFact:   root._ballast ? root._ballast.blower1 : null
                valveFact:    root._ballast ? root._ballast.valve1 : null
            }

            BladderCard {
                cardTitle:     qsTr("右主囊")
                bladderIndex:  2
                pressureFact: root._ballast ? root._ballast.bladderPressure2 : null
                blowerFact:   root._ballast ? root._ballast.blower2 : null
                valveFact:    root._ballast ? root._ballast.valve2 : null
            }

            BladderCard {
                cardTitle:     qsTr("右副囊")
                bladderIndex:  3
                pressureFact: root._ballast ? root._ballast.bladderPressure3 : null
                blowerFact:   root._ballast ? root._ballast.blower3 : null
                valveFact:    root._ballast ? root._ballast.valve3 : null
            }
        }
    }
}
