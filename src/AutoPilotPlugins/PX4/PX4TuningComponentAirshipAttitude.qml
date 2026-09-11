import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

ColumnLayout {
    property real _availableHeight: availableHeight
    property real _availableWidth:  availableWidth

    FactPanelController {
        id: controller
    }

    // 参数存在性检查：飞艇固件未提供 AS_ 参数时隐藏整个页面内容
    property bool _paramsAvailable: controller.parameterExists(-1, "AS_PIT_P")

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        visible: _paramsAvailable

        ColumnLayout {
            width: parent.width
            spacing: ScreenTools.defaultFontPixelHeight / 2

            // 俯仰角外环 PID
            QGCGroupBox {
                title: qsTr("Pitch Outer Loop (Angle)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PIT_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PIT_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PIT_IMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PIT_FF")
                    }
                }
            }

            // 俯仰角速率内环 PID
            QGCGroupBox {
                title: qsTr("Pitch Rate Inner Loop")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PR_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PR_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PR_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PR_IMAX")
                    }
                }
            }

            // 偏航角外环 PID
            QGCGroupBox {
                title: qsTr("Yaw Outer Loop (Angle)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YAW_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YAW_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YAW_IMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YAW_TMAX")
                    }
                }
            }

            // 偏航角速率内环 PID
            QGCGroupBox {
                title: qsTr("Yaw Rate Inner Loop")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YR_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YR_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YR_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YR_IMAX")
                    }
                }
            }

            // 横滚角外环/速率内环 PID（V2 新增：上升电机左右差动闭环，
            // 气囊不参与横滚，02_parameters.md §4）
            QGCGroupBox {
                title: qsTr("Roll Outer Loop (Angle)")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ROLL_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ROLL_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ROLL_IMAX")
                    }
                }
            }

            // 横滚速率内环 PID
            QGCGroupBox {
                title: qsTr("Roll Rate Inner Loop")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_RR_P")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_RR_I")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_RR_D")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_RR_IMAX")
                    }
                }
            }

            // 角速率限制
            QGCGroupBox {
                title: qsTr("Rate Limits")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_PIT_RMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_YAW_RMAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "AS_ROLL_RMAX")
                    }
                }
            }
        }
    }

    // 参数不可用时的提示
    QGCLabel {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !_paramsAvailable
        text: qsTr("Airship attitude parameters (AS_*) not found. Please connect to the airship vehicle.")
        wrapMode: Text.Wrap
    }
}
