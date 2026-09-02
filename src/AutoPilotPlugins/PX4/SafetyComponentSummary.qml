import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.FactControls
import QGroundControl.Controls

Item {
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight
    width: parent.width  // grows when Loader is wider than implicitWidth

    FactPanelController { id: controller; }

    // Guard RTL fact lookups: the airship firmware (RTL = hover in place, never
    // lands) intentionally has no RTL_* params. Requesting them would trigger
    // the "Parameters are missing from firmware" alert.
    property bool _hasRtlParams: controller.parameterExists(-1, "RTL_RETURN_ALT")
    property Fact   returnAltFact:      _hasRtlParams ? controller.getParameterFact(-1, "RTL_RETURN_ALT") : null
    property Fact   _descendAltFact:    _hasRtlParams ? controller.getParameterFact(-1, "RTL_DESCEND_ALT") : null
    property Fact   landDelayFact:      _hasRtlParams ? controller.getParameterFact(-1, "RTL_LAND_DELAY") : null
    property Fact   commRCLossFact:     controller.getParameterFact(-1, "COM_RC_LOSS_T")
    property Fact   lowBattAction:      controller.getParameterFact(-1, "COM_LOW_BAT_ACT")
    property Fact   rcLossAction:       controller.getParameterFact(-1, "NAV_RCL_ACT")
    property Fact   dataLossAction:     controller.getParameterFact(-1, "NAV_DLL_ACT")
    property Fact   _rtlLandDelayFact:  _hasRtlParams ? controller.getParameterFact(-1, "RTL_LAND_DELAY") : null
    property int    _rtlLandDelayValue: _rtlLandDelayFact ? _rtlLandDelayFact.value : 0

    ColumnLayout {
        id: mainLayout
        spacing: 0

        VehicleSummaryRow {
            labelText: qsTr("Low Battery Failsafe")
            valueText: lowBattAction ? lowBattAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RC/Joystick Loss Failsafe")
            valueText: rcLossAction ? rcLossAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RC/Joystick Loss Timeout")
            valueText: commRCLossFact ? commRCLossFact.valueString + " " + commRCLossFact.units : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("Data Link Loss Failsafe")
            valueText: dataLossAction ? dataLossAction.enumStringValue : ""
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL Climb To")
            valueText: returnAltFact ? returnAltFact.valueString + " " + returnAltFact.units : ""
            visible:    _hasRtlParams
        }

        VehicleSummaryRow {
            labelText: qsTr("RTL, Then")
            valueText: _rtlLandDelayValue === 0 ?
                           qsTr("Land immediately") :
                           (_rtlLandDelayValue < 0 ?
                                qsTr("Loiter and do not land") :
                                qsTr("Loiter and land after specified time"))
            visible:    _hasRtlParams
        }

        VehicleSummaryRow {
            labelText: qsTr("Loiter Alt")
            valueText: _descendAltFact ? _descendAltFact.valueString + " " + _descendAltFact.units : ""
            visible:    _hasRtlParams && _rtlLandDelayValue !== 0
        }

        VehicleSummaryRow {
            labelText: qsTr("Land Delay")
            valueText: _rtlLandDelayFact ? _rtlLandDelayValue + " " + _rtlLandDelayFact.units : ""
            visible:    _rtlLandDelayValue > 0
        }
    }
}
