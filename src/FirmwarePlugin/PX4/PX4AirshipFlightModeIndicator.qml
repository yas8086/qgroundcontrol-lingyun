import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.ScreenTools

// 飞艇专用工具栏扩展指示器
// 显示飞艇关键参数：起飞高度、速度限制、浮力控制状态
ColumnLayout {
    spacing: ScreenTools.defaultFontPixelHeight / 2

    FactPanelController {
        id: controller
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // 飞艇参数存在性检查
    property bool _paramsAvailable: controller.parameterExists(-1, "AS_TAKEOFF_ALT")

    // 飞艇模式语义说明(与多旋翼差异, 见PX4文档06_qgc_dev_guide 1.3)
    property string _flightMode:        _activeVehicle ? _activeVehicle.flightMode : ""
    readonly property bool _isHoldOrRTL:    _flightMode === "Hold" || _flightMode === "RTL"
    readonly property bool _isTakeoffMode:  _flightMode === "Takeoff"
    readonly property bool _isLandMode:     _flightMode === "Land"

    // 速度与高度限制
    SettingsGroupLayout {
        title: qsTr("Flight Limits")
        Layout.fillWidth: true
        visible: _paramsAvailable

        LabelledFactSlider {
            Layout.fillWidth: true
            label: qsTr("Max Climb Rate")
            fact: controller.getParameterFact(-1, "AS_ALT_VMAX")
            from: fact.min
            to: fact.max
        }
        LabelledFactSlider {
            Layout.fillWidth: true
            label: qsTr("Max Horizontal Speed")
            fact: controller.getParameterFact(-1, "AS_VEL_XY_MAX")
            from: fact.min
            to: fact.max
        }
        LabelledFactSlider {
            Layout.fillWidth: true
            label: qsTr("Takeoff Altitude")
            fact: controller.getParameterFact(-1, "AS_TAKEOFF_ALT")
            from: fact.min
            to: fact.max
        }
    }

    // 模式语义说明(飞艇与多旋翼行为差异, 避免误解)
    ColumnLayout {
        spacing: ScreenTools.defaultFontPixelHeight / 4
        Layout.fillWidth: true

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("Airship Mode Semantics")
            font.bold: true
            visible: _paramsAvailable
        }
        // RTL/Loiter: 原地定高悬停, 不返航(06 1.3.1)
        QGCLabel {
            Layout.fillWidth:     true
            visible:              _paramsAvailable && _isHoldOrRTL
            text:                 qsTr("⏸ Hold/RTL: hovering in place at current altitude — the airship does NOT return home.")
            wrapMode:             Text.WordWrap
            color:                qgcPal.warningText
        }
        // Takeoff: 完成后自动切Loiter(06 1.3.4)
        QGCLabel {
            Layout.fillWidth:     true
            visible:              _paramsAvailable && _isTakeoffMode
            text:                 qsTr("▲ Takeoff: auto-switches to Loiter when complete.")
            wrapMode:             Text.WordWrap
            color:                qgcPal.warningText
        }
        // Land: 3m自动disarm(06 1.3.3)
        QGCLabel {
            Layout.fillWidth:     true
            visible:              _paramsAvailable && _isLandMode
            text:                 qsTr("▼ Land: auto-disarm at 3 m altitude.")
            wrapMode:             Text.WordWrap
            color:                qgcPal.warningText
        }
    }


    // 浮力控制状态
    SettingsGroupLayout {
        title: qsTr("Buoyancy Control")
        Layout.fillWidth: true
        visible: _paramsAvailable

        LabelledFactComboBox {
            Layout.fillWidth: true
            label: qsTr("Buoyancy Assist")
            fact: controller.getParameterFact(-1, "BALLOON_AST_EN")
            indexModel: [ qsTr("Disabled"), qsTr("Enabled") ]
        }
        LabelledFactSlider {
            Layout.fillWidth: true
            label: qsTr("Altitude Deadzone")
            fact: controller.getParameterFact(-1, "BALLOON_DEADZONE")
            from: fact.min
            to: fact.max
        }
    }

    // 参数不可用时的提示
    QGCLabel {
        Layout.fillWidth: true
        visible: !_paramsAvailable
        text: qsTr("Airship parameters not available")
        wrapMode: Text.Wrap
    }
}
