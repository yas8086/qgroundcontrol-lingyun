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

    property bool _paramsAvailable: controller.parameterExists(-1, "AS_ALT_P")

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: _paramsAvailable

        ColumnLayout {
            width: parent.width
            spacing: ScreenTools.defaultFontPixelHeight / 2

            // 高度 PID
            QGCGroupBox {
                title: qsTr("Altitude Control")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_IMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_VMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_VFF")
                    }
                }
            }

            // 高度限位
            QGCGroupBox {
                title: qsTr("Altitude Limits")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_MAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_MIN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_SOFT")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ALT_SRATE")
                    }
                }
            }

            // 水平位置/速度控制
            QGCGroupBox {
                title: qsTr("Horizontal Position & Velocity")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_VEL_XY_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_VEL_XY_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_VEL_XY_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_VEL_XY_IMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_POS_XY_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_VEL_XY_MAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_POS_XY_MAX")
                    }
                }
            }

            // 起飞参数
            QGCGroupBox {
                title: qsTr("Takeoff")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TAKEOFF_ALT")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TKF_HOLD_T")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TKF_ALT_TOL")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TAKEOFF_RAMP")
                    }
                }
            }

            // 降落参数（分阶段下降速度）
            QGCGroupBox {
                title: qsTr("Land (Staged Descent)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_LND_DONE_ALT")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_LND_VHI")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_LND_VMID")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_LND_VLO")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_LND_VGND")
                    }
                }
            }

            // 自动测试/调参（高级）
            QGCGroupBox {
                title: qsTr("Auto Test & Tuning (Advanced)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TST_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TST_PIT")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_TST_YAW")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_AT_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_AT_AMP")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_AT_DUR")
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
        text: qsTr("Airship position parameters (AS_*) not found. Please connect to the airship vehicle.")
        wrapMode: Text.Wrap
    }
}
