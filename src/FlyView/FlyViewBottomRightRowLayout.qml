import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

RowLayout {
    id:                 root

    property var  _activeVehicle:     globals.activeVehicle
    property bool _isAirship:         _activeVehicle && _activeVehicle.airship
    // !== false 而非 === true：载具连接过程中 flyViewSettings/rawValue 会瞬间求值为 undefined，
    // 若按 false 处理会导致 Loader 销毁重建（面板闪断）；undefined 时维持显示
    property bool _showAirshipBar:    QGroundControl.settingsManager.flyViewSettings.airshipShowTelemetryBar.rawValue !== false

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
