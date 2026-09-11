import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// 飞艇浮力控制参数页（02_parameters.md §9/§10 分组契约）
// 注意：V2 已删除 TRIM_BALLOON_* 全族（四囊同步，气囊不参与横滚）；
//       BALLOON_THRSHLD 为死参数（定义+加载但零引用），均不展示。
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

            // 浮力辅助控制（高度 PID）
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
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_RATE_MAX")
                    }
                }
            }

            // 硬件参数（气囊/风机/阀门物理特性）
            QGCGroupBox {
                title: qsTr("Hardware")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_M_MAX")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BLWR_FLOW")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "VALVE_FLOW_MAX")
                    }
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

            // 互锁（防频繁启停/管道串压）
            QGCGroupBox {
                title: qsTr("Interlock")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_MIN_ON")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_SWT_GD")
                    }
                }
            }

            // 安全（紧急排气/输出使能）
            QGCGroupBox {
                title: qsTr("Safety")
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 4
                    width: parent.width

                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_EMG_EN")
                    }
                    LabelledFactTextField {
                        Layout.fillWidth: true
                        fact: controller.getParameterFact(-1, "BALLOON_OUT_EN")
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
