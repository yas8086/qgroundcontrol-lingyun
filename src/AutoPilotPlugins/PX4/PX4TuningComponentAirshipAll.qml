import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

PX4TuningComponent {
    model: ListModel {
        ListElement {
            buttonText: qsTr("Attitude")
            tuningPage: "PX4TuningComponentAirshipAttitude.qml"
        }
        ListElement {
            buttonText: qsTr("Position")
            tuningPage: "PX4TuningComponentAirshipPosition.qml"
        }
        ListElement {
            buttonText: qsTr("Ballast")
            tuningPage: "PX4TuningComponentAirshipBallast.qml"
        }
    }
}
