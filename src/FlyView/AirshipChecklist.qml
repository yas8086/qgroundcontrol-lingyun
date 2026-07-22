import QtQuick
import QtQuick.Controls
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    property var model: listModel
    PreFlightCheckModel {
        id:     listModel

        // 第一组：初始检查
        PreFlightCheckGroup {
            name: qsTr("Airship Initial Checks")

            PreFlightCheckButton {
                name:           qsTr("Hardware")
                manualText:     qsTr("Airship envelope intact? Blowers and valves responding? Motor mounts secured?")
            }

            PreFlightBatteryCheck {
                failurePercent:                 40
                allowFailurePercentOverride:    false
            }

            PreFlightSensorsHealthCheck {
            }

            PreFlightGPSCheck {
                failureSatCount:        9
                allowOverrideSatCount:  true
            }

            PreFlightRCCheck {
            }
        }

        // 第二组：飞艇专用检查
        PreFlightCheckGroup {
            name: qsTr("Airship-Specific Checks")

            PreFlightCheckButton {
                name:           qsTr("Buoyancy")
                manualText:     qsTr("Net buoyancy near zero? Left-right trim balanced? Blower/valve response verified?")
            }

            PreFlightCheckButton {
                name:           qsTr("Altitude Limits")
                manualText:     qsTr("AS_ALT_MAX/MIN set correctly? Current altitude below AS_TAKEOFF_ALT?")
            }

            PreFlightCheckButton {
                name:           qsTr("Mission")
                manualText:     qsTr("Mission valid? Waypoint spacing >50m? Turn angles <30deg? Landing zone clear?")
            }

            PreFlightSoundCheck {
            }
        }

        // 第三组：最终准备
        PreFlightCheckGroup {
            name: qsTr("Final Preparations Before Launch")

            PreFlightCheckButton {
                name:           qsTr("Wind & Weather")
                manualText:     qsTr("Wind speed within limits for airship operations?")
            }

            PreFlightCheckButton {
                name:           qsTr("Flight Area")
                manualText:     qsTr("Launch/landing area clear? Flight path free of obstacles?")
            }

            PreFlightCheckButton {
                name:           qsTr("Envelope Pressure")
                manualText:     qsTr("Helium pressure normal? No leaks detected?")
            }
        }
    }
}
