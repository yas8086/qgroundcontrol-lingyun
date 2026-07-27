import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

SelectableControl {
    z:                      QGroundControl.zOrderWidgets
    selectionUIRightAnchor: true
    selectedControl:        QGroundControl.settingsManager.flyViewSettings.instrumentQmlFile2

    property var  missionController:    _missionController
    property real extraInset:           innerControl.extraInset
    property real extraValuesWidth:     innerControl.extraValuesWidth

    // Airship press-and-hold panel visibility popup (task-5).
    // Long-press on the instrument panel opens a popup with switches to
    // toggle the Telemetry Bar (airshipShowTelemetryBar) and the
    // Multi-Vehicle Panel (enableMultiVehiclePanel). Click events pass
    // through to the SelectableControl base so the existing right-click /
    // selection UI behaviour is preserved.
    property var _flyViewSettings: QGroundControl.settingsManager.flyViewSettings

    QGCMouseArea {
        anchors.fill:           parent
        acceptedButtons:        Qt.LeftButton
        propagateComposedEvents: true
        // Only handle press-and-hold; do not intercept onClicked so clicks
        // continue to propagate to the SelectableControl's QGCMouseArea
        // (which handles right-click -> selection UI on desktop).
        onPressAndHold: (mouse) => {
            visibilityPopupFactory.open({})
            mouse.accepted = true
        }
    }

    QGCPopupDialogFactory {
        id:             visibilityPopupFactory
        dialogComponent: visibilityPopup
    }

    Component {
        id: visibilityPopup

        QGCPopupDialog {
            title:   qsTr("Show / Hide Panels")
            buttons: Dialog.Close

            ColumnLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCCheckBoxSlider {
                    text:     qsTr("Telemetry Bar")
                    checked:   _flyViewSettings.airshipShowTelemetryBar.rawValue
                    onClicked: _flyViewSettings.airshipShowTelemetryBar.rawValue = checked
                }

                QGCCheckBoxSlider {
                    text:     qsTr("Multi-Vehicle Panel")
                    checked:   QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.rawValue
                    onClicked: QGroundControl.settingsManager.appSettings.enableMultiVehiclePanel.rawValue = checked
                }
            }
        }
    }
}
