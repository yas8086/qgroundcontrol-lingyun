import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.ScreenTools

ColumnLayout {
    property real _availableHeight: availableHeight
    property real _availableWidth:  availableWidth

    FactPanelController {
        id: controller
    }

    property bool _paramsAvailable: controller.parameterExists(-1, "BALLOON_P_GAIN")

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: _paramsAvailable

        ColumnLayout {
            width: parent.width
            spacing: ScreenTools.defaultFontPixelHeight / 2

            // 浮力辅助控制
            QGCGroupBox {
                title: qsTr("Buoyancy Assist Control")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_AST_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_DEADZONE")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_THRSHLD")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_RATE_MAX")
                    }
                }
            }

            // 浮力 PID
            QGCGroupBox {
                title: qsTr("Buoyancy PID")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_P_GAIN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_I_GAIN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_D_GAIN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_I_MAX")
                    }
                }
            }

            // 鼓风机与阀门
            QGCGroupBox {
                title: qsTr("Blower & Valve")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BLOWER_TAU")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "VALVE_OPEN_DELAY")
                    }
                }
            }

            // 左右浮力配平
            QGCGroupBox {
                title: qsTr("Left-Right Buoyancy Trim")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "TRIM_BALLOON_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "TRIM_BALLOON_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "TRIM_BALLOON_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "TRIM_BALLOON_IMX")
                    }
                }
            }

            // 横滚主动控制（四气囊浮力差）
            QGCGroupBox {
                title: qsTr("Roll Control (4-Ballast Active)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_R_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_R_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_R_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_R_IMX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_RR_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_RR_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_R_MAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_M_MAX")
                    }
                }
            }

            // 风机与阀门执行器参数
            QGCGroupBox {
                title: qsTr("Blower & Valve Actuator")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BLWR_FLOW")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "VALVE_HYST")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "VALVE_MIN_T")
                    }
                }
            }
        }
    }

    QGCLabel {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !_paramsAvailable
        text: qsTr("Ballast control parameters (BALLOON_*) not found. Please connect to the airship vehicle.")
        wrapMode: Text.Wrap
    }
}
