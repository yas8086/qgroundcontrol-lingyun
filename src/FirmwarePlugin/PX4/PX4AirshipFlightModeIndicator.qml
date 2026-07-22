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

    // 飞艇参数存在性检查
    property bool _paramsAvailable: controller.parameterExists(-1, "AS_TAKEOFF_ALT")

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
        LabelledFactSlider {
            Layout.fillWidth: true
            label: qsTr("Switch Threshold")
            fact: controller.getParameterFact(-1, "BALLOON_THRSHLD")
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
