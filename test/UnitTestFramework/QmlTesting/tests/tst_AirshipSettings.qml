import QtQuick
import QtTest
import QGroundControl

/// Tests for airship-specific FlyViewSettings added in task-1.
///
/// Note: QGCQmlQuickTests is an isolated Qt6 executable that does not link
/// QGroundControlModule, so the QGroundControl QML singleton is not registered
/// in this process. The runtime Fact tests below skip when the singleton is
/// absent. C++ registration is validated via compilation of
/// DEFINE_SETTINGFACT/DECLARE_SETTINGSFACT, and JSON metadata is validated via
/// `python3 -m json.tool` parsing of FlyView.SettingsGroup.json.

TestCase {
    name: "AirshipSettingsTest"

    function test_airshipInstrumentPageCount_default() {
        if (typeof QGroundControl === "undefined") {
            skip("QGroundControl singleton not available in QGCQmlQuickTests process")
        }
        var f = QGroundControl.settingsManager.flyViewSettings.airshipInstrumentPageCount
        compare(f.rawValue, 3, "default page count is 3")
    }

    function test_airshipShowTelemetryBar_default() {
        if (typeof QGroundControl === "undefined") {
            skip("QGroundControl singleton not available in QGCQmlQuickTests process")
        }
        var f = QGroundControl.settingsManager.flyViewSettings.airshipShowTelemetryBar
        compare(f.rawValue, true, "default telemetry bar visible is true")
    }
}
