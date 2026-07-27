import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

RowLayout {
    id:                 root

    property var  _activeVehicle:     globals.activeVehicle
    property bool _isAirship:         _activeVehicle && _activeVehicle.airship
    property bool _showAirshipBar:    QGroundControl.settingsManager.flyViewSettings.airshipShowTelemetryBar.rawValue

    // Airship-specific paged instrument panel; loaded only for airship vehicles
    // when FlyViewSettings.airshipShowTelemetryBar is enabled. Mutually exclusive
    // with the TelemetryValuesBar below via Loader.active / visible.
    Loader {
        Layout.alignment:       Qt.AlignBottom
        active:                 root._isAirship && root._showAirshipBar
        sourceComponent:        airshipPagedBarComponent
    }

    Component {
        id: airshipPagedBarComponent
        AirshipPagedValuesBar {}
    }

    // Non-airship (or airship with telemetry bar hidden): original TelemetryValuesBar
    TelemetryValuesBar {
        Layout.alignment:       Qt.AlignBottom
        extraWidth:             instrumentPanel.extraValuesWidth
        settingsGroup:          factValueGrid.telemetryBarSettingsGroup
        specificVehicleForCard: null // Tracks active vehicle
        visible:                !(root._isAirship && root._showAirshipBar)
    }

    FlyViewInstrumentPanel {
        id:                 instrumentPanel
        Layout.alignment:   Qt.AlignBottom
        visible:            QGroundControl.corePlugin.options.flyView.showInstrumentPanel && _showSingleVehicleUI
    }
}
