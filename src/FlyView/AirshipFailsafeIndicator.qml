import QtQuick

import QGroundControl
import QGroundControl.Controls

// 灵云01: att_control 内部 failsafe 增强感知(PX4文档 06_qgc_dev_guide §3)
//
// 内部 failsafe(RC/GCS 任一丢失+5s → 悬停保护)仅写 console 日志 [FAILSAFE],
// 不发 STATUSTEXT, QGC 标准告警链路看不到。本组件用运行特征近似判定:
//   airship + armed + 模式 Hold + 地速/垂直速度≈0 持续 60s → 疑似悬停保护激活
// 提示用户检查链路与控制台日志。风大悬停漂移(地速>0.5m/s)时会漏报, 属尽力而为增强。
Rectangle {
    id:             root
    anchors.top:               parent.top
    anchors.horizontalCenter:  parent.horizontalCenter
    anchors.topMargin:         ScreenTools.defaultFontPixelHeight * 1.5
    z:                         QGroundControl.zOrderTopMost
    width:            label.width  + _margin * 2
    height:           label.height + _margin
    radius:           _margin * 0.5
    color:            "#CCFF9800"
    visible:          _suspicious && !_dismissed

    property var    _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property real   _margin:        ScreenTools.defaultFontPixelHeight / 2
    property bool   _airship:       _activeVehicle && _activeVehicle.airship
    property bool   _armed:         _activeVehicle ? _activeVehicle.armed : false
    property string _flightMode:    _activeVehicle ? _activeVehicle.flightMode : ""
    // 静止特征: 地速<0.5m/s 且 垂直速度<0.3m/s(与固件 AirshipLandDetector 判据同源)
    property bool   _hoverStill:    _activeVehicle
                                    ? Math.abs(_activeVehicle.groundSpeed.rawValue) < 0.5
                                   && Math.abs(_activeVehicle.climbRate.rawValue)  < 0.3
                                    : false
    property int    _stillSeconds:  0
    property bool   _dismissed:     false
    property bool   _suspicious:    _airship && _armed && _flightMode === "Hold" && _hoverStill && _stillSeconds >= 60

    Timer {
        interval: 1000
        running:  root._airship && root._armed
        repeat:   true
        onTriggered: root._stillSeconds = root._hoverStill ? root._stillSeconds + 1 : 0
    }

    QGCLabel {
        id:         label
        anchors.centerIn: parent
        text:       qsTr("疑似内部 failsafe 悬停保护已激活 (静止 %1s): 推进已停用, RC/GCS 链路请自查, 详见控制台日志 [FAILSAFE]").arg(root._stillSeconds)
        color:      "black"
        font.bold:  true
    }

    // 点击关闭本次提示(_dismissed 独立于 _suspicious 绑定, 不破坏判定)
    QGCMouseArea {
        anchors.fill: parent
        onClicked:    root._dismissed = true
    }
}
