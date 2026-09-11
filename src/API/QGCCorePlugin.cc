#include "QGCCorePlugin.h"
#include "AppSettings.h"
#include "MavlinkSettings.h"
#include "FactMetaData.h"
#include "QGCMAVLink.h"
#ifdef QGC_GST_STREAMING
#include "GStreamer.h"
#endif
#include "HorizontalFactValueGrid.h"
#include "InstrumentValueData.h"
#include "JoystickManager.h"
#include "MAVLinkMessageType.h"
#include "QGCLoggingCategory.h"
#include "QGCOptions.h"
#include "QmlComponentInfo.h"
#include "QmlObjectListModel.h"
#ifdef QGC_QT_STREAMING
#include "QtMultimediaReceiver.h"
#endif
#include "SettingsManager.h"
#include "VideoReceiver.h"
#include "SurveyPlanCreator.h"
#include "CorridorScanPlanCreator.h"
#include "StructureScanPlanCreator.h"
#include "SurveyComplexItem.h"
#include "CorridorScanComplexItem.h"
#include "StructureScanComplexItem.h"
#include "FixedWingLandingComplexItem.h"
#include "VTOLLandingComplexItem.h"
#include "Vehicle.h"
#include "BlankPlanCreator.h"
#include "ComplexMissionItem.h"
#include "PlanMasterController.h"

#ifdef QGC_CUSTOM_BUILD
#include CUSTOMHEADER
#endif

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtCore/QSettings>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlContext>
#include <QtQuick/QQuickItem>

QGC_LOGGING_CATEGORY(QGCCorePluginLog, "API.QGCCorePlugin");

#ifndef QGC_CUSTOM_BUILD
Q_APPLICATION_STATIC(QGCCorePlugin, _qgcCorePluginInstance);
#endif

QGCCorePlugin::QGCCorePlugin(QObject *parent)
    : QObject(parent)
    , _defaultOptions(new QGCOptions(this))
    , _emptyCustomMapItems(new QmlObjectListModel(this))
{
    qCDebug(QGCCorePluginLog) << this;
}

QGCCorePlugin::~QGCCorePlugin()
{
    qCDebug(QGCCorePluginLog) << this;
}

QGCCorePlugin *QGCCorePlugin::instance()
{
#ifndef QGC_CUSTOM_BUILD
    return _qgcCorePluginInstance();
#else
    return CUSTOMCLASS::instance();
#endif
}

const QVariantList &QGCCorePlugin::analyzePages()
{
    // Log Viewer is excluded on mobile (Android/iOS) because parsing large log files
    // (e.g. 900 MB ULog files with 1000+ fields) exhausts the mobile heap, causing
    // OOM crashes. Proper mobile support requires time-bucketed downsampling and will
    // be addressed in a future major release.
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    static const QVariantList analyzeList = {
#else
    static const QVariantList analyzeList = {
        QVariant::fromValue(new QmlComponentInfo(
            tr("Log Viewer"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/LogViewer/LogViewerPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/MAVLinkInspector.svg")))),
#endif
        QVariant::fromValue(new QmlComponentInfo(
            tr("Onboard Logs"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/OnboardLogs/OnboardLogPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/OnboardLogIcon.svg")),
            nullptr, true /* requiresVehicle */)),
        QVariant::fromValue(new QmlComponentInfo(
            tr("Onboard Logs (FTP)"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/OnboardLogsFtp/OnboardLogFtpPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/OnboardLogIcon.svg")),
            nullptr, true /* requiresVehicle */)),
        QVariant::fromValue(new QmlComponentInfo(
            tr("GeoTag Images"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/GeoTag/GeoTagPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/GeoTag/GeoTagIcon.svg")))),
        QVariant::fromValue(new QmlComponentInfo(
            tr("MAVLink Console"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/MAVLinkConsole/MAVLinkConsolePage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/MAVLinkConsoleIcon.svg")),
            nullptr, true /* requiresVehicle */)),
        QVariant::fromValue(new QmlComponentInfo(
            tr("MAVLink Inspector"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/MAVLinkInspector/MAVLinkInspectorPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/MAVLinkInspector.svg")),
            nullptr, true /* requiresVehicle */)),
        QVariant::fromValue(new QmlComponentInfo(
            tr("Vibration"),
            QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AnalyzeView/Vibration/VibrationPage.qml")),
            QUrl::fromUserInput(QStringLiteral("qrc:/qmlimages/VibrationPageIcon")),
            nullptr, true /* requiresVehicle */)),
    };

    return analyzeList;
}

QGCOptions *QGCCorePlugin::options()
{
    return _defaultOptions;
}

const QmlObjectListModel *QGCCorePlugin::customMapItems()
{
    return _emptyCustomMapItems;
}

void QGCCorePlugin::adjustSettingMetaData(const QString &settingsGroup, FactMetaData &metaData, bool &userVisible)
{
#ifdef Q_OS_ANDROID
    Q_UNUSED(userVisible);
#endif

    if (settingsGroup == AppSettings::settingsGroup) {
        if (metaData.name() == AppSettings::indoorPaletteName) {
            QVariant outdoorPalette;
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
            outdoorPalette = 0;
#else
            outdoorPalette = 1;
#endif
            metaData.setRawDefaultValue(outdoorPalette);
            return;
        }
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
        else if (metaData.name() == MavlinkSettings::telemetrySaveName) {
            metaData.setRawDefaultValue(false);
            return;
        }
#endif
#ifndef Q_OS_ANDROID
        else if (metaData.name() == AppSettings::androidDontSaveToSDCardName) {
            userVisible = false;
            return;
        }
#endif
    }
}

QString QGCCorePlugin::showAdvancedUIMessage() const
{
    return tr("WARNING: You are about to enter Advanced Mode. "
              "If used incorrectly, this may cause your vehicle to malfunction thus voiding your warranty. "
              "You should do so only if instructed by customer support. "
              "Are you sure you want to enable Advanced Mode?");
}

void QGCCorePlugin::factValueGridCreateDefaultSettings(FactValueGrid* factValueGrid)
{
    // Airship paged instrument panel: inject airship-specific defaults per page
    // instead of the generic default layout. The QML Component.onCompleted guard
    // (columns.count===0) never triggers because this virtual method already
    // fills defaults during FactValueGrid::componentComplete.
    const QString settingsGroup = factValueGrid->settingsGroup();
    if (settingsGroup.startsWith(QStringLiteral("AirshipInstr.Page"))) {
        _createAirshipPagedDefaultSettings(factValueGrid);
        return;
    }

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    FactValueGrid::FontSize defaultFontSize = FactValueGrid::DefaultFontSize;
#else
    FactValueGrid::FontSize defaultFontSize = FactValueGrid::MediumFontSize;
#endif

    if (factValueGrid->specificVehicleForCard()) {
        bool includeFWValues = factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassFixedWing || factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassVTOL || factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassAirship;

        factValueGrid->setFontSize(defaultFontSize);
        factValueGrid->appendColumn();
        factValueGrid->appendColumn();

        int rowIndex = 0;
        int colIndex = 0;

        // first cell
        QmlObjectListModel* column = factValueGrid->columns()->value<QmlObjectListModel*>(colIndex++);
        InstrumentValueData* value = column->value<InstrumentValueData*>(rowIndex);
        value->setFact("Vehicle", "AltitudeRelative");
        value->setIcon("arrow-thick-up.svg");
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);

        // second cell
        column = factValueGrid->columns()->value<QmlObjectListModel*>(colIndex++);
        value = column->value<InstrumentValueData*>(rowIndex);
        if (includeFWValues) {
            value->setFact("Vehicle", "AirSpeed");
            value->setText("AirSpd");
            value->setShowUnits(true);
        } else {
            value->setFact("Vehicle", "GroundSpeed");
            value->setIcon("arrow-simple-right.svg");
            value->setText(value->fact()->shortDescription());
            value->setShowUnits(true);
        }
    } else {
        const bool includeFWValues = ((factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassFixedWing) || (factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassVTOL) || (factValueGrid->vehicleClass() == QGCMAVLink::VehicleClassAirship));

        factValueGrid->setFontSize(defaultFontSize);

        (void) factValueGrid->appendColumn();
        (void) factValueGrid->appendColumn();
        (void) factValueGrid->appendColumn();
        if (includeFWValues) {
            (void) factValueGrid->appendColumn();
        }
        factValueGrid->appendRow();

        int rowIndex = 0;
        QmlObjectListModel *column = factValueGrid->columns()->value<QmlObjectListModel*>(0);

        InstrumentValueData *value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("AltitudeRelative"));
        value->setIcon(QStringLiteral("arrow-thick-up.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);

        value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("DistanceToHome"));
        value->setIcon(QStringLiteral("bookmark copy 3.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);

        rowIndex = 0;
        column = factValueGrid->columns()->value<QmlObjectListModel*>(1);

        value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("ClimbRate"));
        value->setIcon(QStringLiteral("arrow-simple-up.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);

        value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("GroundSpeed"));
        value->setIcon(QStringLiteral("arrow-simple-right.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);

        if (includeFWValues) {
            rowIndex = 0;
            column = factValueGrid->columns()->value<QmlObjectListModel*>(2);

            value = column->value<InstrumentValueData*>(rowIndex++);
            value->setFact(QStringLiteral("Vehicle"), QStringLiteral("AirSpeed"));
            value->setText(QStringLiteral("AirSpd"));
            value->setShowUnits(true);

            value = column->value<InstrumentValueData*>(rowIndex++);
            value->setFact(QStringLiteral("Vehicle"), QStringLiteral("ThrottlePct"));
            value->setText(QStringLiteral("Thr"));
            value->setShowUnits(true);
        }

        rowIndex = 0;
        column = factValueGrid->columns()->value<QmlObjectListModel*>(includeFWValues ? 3 : 2);

        value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("FlightTime"));
        value->setIcon(QStringLiteral("timer.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(false);

        value = column->value<InstrumentValueData*>(rowIndex++);
        value->setFact(QStringLiteral("Vehicle"), QStringLiteral("FlightDistance"));
        value->setIcon(QStringLiteral("travel-walk.svg"));
        value->setText(value->fact()->shortDescription());
        value->setShowUnits(true);
    }
}

void QGCCorePlugin::_createAirshipPagedDefaultSettings(FactValueGrid *factValueGrid)
{
    // Extract page index from settingsGroup "AirshipInstr.PageN".
    const QString settingsGroup = factValueGrid->settingsGroup();
    const int prefixLen = static_cast<int>(QStringLiteral("AirshipInstr.Page").length());
    int pageIndex = settingsGroup.mid(prefixLen).toInt();

    // Airship default telemetry: 3 pages displayed side by side at the bottom.
    // Each page is a single narrow column of 3 values (factName nullptr marks
    // an empty slot) so the 3 pages fit on one row without overlapping.
    struct AirshipIVD {
        const char *group;
        const char *factName;
        const char *icon;
        // u8 literals keep the Chinese labels UTF-8 encoded on all compilers
        // (plain narrow literals would be interpreted as ACP on MSVC).
        const char8_t *text;
    };

    static constexpr AirshipIVD kPages[3][3] = {
        // Page 0: flight core
        {
            {"Vehicle", "AltitudeRelative", "arrow-thick-up.svg", u8"相对高度"},
            {"Vehicle", "ClimbRate", "arrow-simple-up.svg", u8"爬升率"},
            {"Vehicle", "Heading", nullptr, u8"航向"},
        },
        // Page 1: buoyancy / attitude
        // ballast FactGroup 为 PX4 十五字段契约（03_interfaces.md §5）：
        // buoy/alt_err/b_mass/blower0~3/valve0~3/bal_p0~3，四囊独立执行器。
        // 每页单列只取 3 个核心，其余浮力字段仍在左下浮力 HUD 完整展示。
        {
            {"ballast", "NetBuoyancy", nullptr, u8"净浮力"},
            {"ballast", "BallastMass", nullptr, u8"囊质量"},
            {"Vehicle", "Roll", nullptr, u8"横滚"},
        },
        // Page 2: energy / mission
        {
            {"Vehicle", "AltitudeAMSL", "arrow-thick-up.svg", u8"海拔高度"},
            {"Vehicle", "ThrottlePct", nullptr, u8"油门%"},
            {"Vehicle", "AirSpeed", nullptr, u8"空速"},
        },
    };

    constexpr int kPageCount = 3;
    if (pageIndex < 0 || pageIndex >= kPageCount) {
        pageIndex = kPageCount - 1;
    }

    constexpr int kMaxRows = 3;
    int rowCount = 0;
    for (int r = 0; r < kMaxRows; r++) {
        if (kPages[pageIndex][r].factName != nullptr) {
            rowCount = r + 1;
        }
    }

    // Single narrow column per page so the 3 pages sit side by side.
    factValueGrid->setMaxColumns(1);
    factValueGrid->setMaxRows(3);
    factValueGrid->setFontSize(FactValueGrid::LargeFontSize);
    // appendColumn() 已给第 1 列 1 个 IVD（rowCount=1），需再 appendRow rowCount-1 次。
    (void) factValueGrid->appendColumn();
    for (int r = 0; r < rowCount - 1; r++) {
        factValueGrid->appendRow();
    }

    QmlObjectListModel *column = factValueGrid->columns()->value<QmlObjectListModel *>(0);
    for (int r = 0; r < rowCount; r++) {
        const AirshipIVD &ivd = kPages[pageIndex][r];
        InstrumentValueData *value = column->value<InstrumentValueData *>(r);
        // Chinese labels are UTF-8 literals; fromLatin1 would garble them.
        value->setFact(QString::fromUtf8(ivd.group), QString::fromUtf8(ivd.factName));
        if (ivd.icon) {
            value->setIcon(QString::fromUtf8(ivd.icon));
        }
        if (ivd.text) {
            value->setText(QString::fromUtf8(ivd.text));
        } else if (value->fact()) {
            value->setText(value->fact()->shortDescription());
        }
        value->setShowUnits(true);
    }
}

void QGCCorePlugin::_migrateAirshipPagedTelemetrySettings(void)
{
    // One-shot migration: remove AirshipInstr.Page* groups saved before the
    // airship-specific paged default layout existed. FactValueGrid loads
    // existing settings in preference to creating defaults, so those stale
    // groups (generic default cells) would shadow the airship layout forever.
    QSettings settings;
    // V2: airship defaults previously shadowed by generic saved layouts.
    // V3: UI reworked to fixed 3 pages with grid size limits; clear layouts
    //     saved during the unlimited-grid editing period.
    // V4: settingsGroup now arrives late through chained QML aliases; layouts
    //     saved while the plugin default injection was bypassed (generic
    //     defaults on all three pages) are cleared once more.
    // V5: pages switched from stacked SwipeView to side-by-side single-column
    //     layout; clear the 2-column layouts saved under the old design.
    // V6: restore factory default sets (user-edited layouts, e.g. a dropped
    //     ClimbRate cell on the flight-core page, are discarded).
    // V8: increase value font size to LargeFontSize; clear fontSize/rowHeight
    //     persisted by earlier builds so the new size takes effect.
    // V9: default cell labels switched to Chinese (相对高度/净浮力/...); clear
    //     layouts saved with English labels so the new defaults apply.
    static const QLatin1String kMigrationKey("AirshipPagedDefaultsV9");
    if (settings.value(kMigrationKey, false).toBool()) {
        return;
    }
    settings.setValue(kMigrationKey, true);
    const QStringList groups = settings.childGroups();
    for (const QString &group : groups) {
        if (group.startsWith(QLatin1String("AirshipInstr.Page"))) {
            settings.remove(group);
        }
    }
    settings.sync();
}

QQmlApplicationEngine *QGCCorePlugin::createQmlApplicationEngine(QObject *parent)
{
    // Must run before any QML page loads: FactValueGrid prefers existing
    // settings over creating defaults, so stale AirshipInstr.Page* groups
    // saved before the airship default layout existed would shadow it forever.
    _migrateAirshipPagedTelemetrySettings();

    QQmlApplicationEngine *const qmlEngine = new QQmlApplicationEngine(parent);
    qmlEngine->addImportPath(QStringLiteral("qrc:/qml"));
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("joystickManager"), JoystickManager::instance());
    return qmlEngine;
}

void QGCCorePlugin::createRootWindow(QQmlApplicationEngine *qmlEngine)
{
    qmlEngine->load(QUrl(QStringLiteral("qrc:/qml/QGroundControl/MainWindow.qml")));
}

VideoReceiver *QGCCorePlugin::createVideoReceiver(QObject *parent)
{
#ifdef QGC_GST_STREAMING
    return GStreamer::createVideoReceiver(parent);
#elif defined(QGC_QT_STREAMING)
    return QtMultimediaReceiver::createVideoReceiver(parent);
#else
    Q_UNUSED(parent);
    return nullptr;
#endif
}

void *QGCCorePlugin::createVideoSink(QQuickItem *widget, QObject *parent)
{
#ifdef QGC_GST_STREAMING
    return GStreamer::createVideoSink(widget, parent);
#elif defined(QGC_QT_STREAMING)
    return QtMultimediaReceiver::createVideoSink(widget, parent);
#else
    Q_UNUSED(widget); Q_UNUSED(parent);
    return nullptr;
#endif
}
void QGCCorePlugin::releaseVideoSink(void *sink)
{
#ifdef QGC_GST_STREAMING
    GStreamer::releaseVideoSink(sink);
#elif defined(QGC_QT_STREAMING)
    QtMultimediaReceiver::releaseVideoSink(sink);
#else
    Q_UNUSED(sink);
#endif
}

const QVariantList &QGCCorePlugin::toolBarIndicators()
{
    static const QVariantList toolBarIndicatorList = QVariantList(
        {
            QVariant::fromValue(QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/Toolbar/RTKGPSIndicator.qml"))),
        }
    );

    return toolBarIndicatorList;
}

QVariantList QGCCorePlugin::firstRunPromptsToShow()
{
    QList<int> rgIdsToShow;

    rgIdsToShow.append(firstRunPromptStdIds());
    rgIdsToShow.append(firstRunPromptCustomIds());

    const QList<int> rgAlreadyShownIds = AppSettings::firstRunPromptsIdsVariantToList(SettingsManager::instance()->appSettings()->firstRunPromptIdsShown()->rawValue());
    for (int idToRemove: rgAlreadyShownIds) {
        (void) rgIdsToShow.removeOne(idToRemove);
    }

    QVariantList rgVarIdsToShow;
    for (int id: rgIdsToShow) {
        rgVarIdsToShow.append(id);
    }

    return rgVarIdsToShow;
}

QString QGCCorePlugin::firstRunPromptResource(int id) const
{
    switch (id) {
    case kInitialSetupPromptId:
        return QStringLiteral("/qml/QGroundControl/FirstRunPromptDialogs/InitialSetupPrompt.qml");
    default:
        return QString();
    }
}

void QGCCorePlugin::_setShowTouchAreas(bool show)
{
    if (show != _showTouchAreas) {
        _showTouchAreas = show;
        emit showTouchAreasChanged(show);
    }
}

void QGCCorePlugin::_setShowAdvancedUI(bool show)
{
    if (show != _showAdvancedUI) {
        _showAdvancedUI = show;
        emit showAdvancedUIChanged(show);
    }
}

QVariantList QGCCorePlugin::complexMissionItemNames(Vehicle *vehicle)
{
    auto makeEntry = [](const char* canonical, const QString& translated) {
        QVariantMap entry;
        entry[QStringLiteral("canonicalName")]  = QString(canonical);
        entry[QStringLiteral("translatedName")] = translated;
        return entry;
    };

    QVariantList items;
    items.append(makeEntry(SurveyComplexItem::canonicalName,       SurveyComplexItem::tr(SurveyComplexItem::canonicalName)));
    items.append(makeEntry(CorridorScanComplexItem::canonicalName, CorridorScanComplexItem::tr(CorridorScanComplexItem::canonicalName)));
    if (vehicle->multiRotor() || vehicle->vtol()) {
        items.append(makeEntry(StructureScanComplexItem::canonicalName, StructureScanComplexItem::tr(StructureScanComplexItem::canonicalName)));
    }
    // Note: Landing pattern items are not added here — they have their own dedicated button
    return items;
}

QList<PlanCreator*> QGCCorePlugin::planCreators(PlanMasterController *planMasterController)
{
    return {
        new SurveyPlanCreator(planMasterController),
        new CorridorScanPlanCreator(planMasterController),
        new StructureScanPlanCreator(planMasterController),
        new BlankPlanCreator(planMasterController),
    };
}

ComplexMissionItem *QGCCorePlugin::createComplexMissionItem(
    const QString &complexItemType,
    PlanMasterController *masterController,
    bool flyView,
    const QString &kmlOrShpFile)
{
    if (complexItemType == SurveyComplexItem::canonicalName || complexItemType == SurveyComplexItem::jsonComplexItemTypeValue) {
        return new SurveyComplexItem(masterController, flyView, kmlOrShpFile);
    } else if (complexItemType == CorridorScanComplexItem::canonicalName || complexItemType == CorridorScanComplexItem::jsonComplexItemTypeValue) {
        return new CorridorScanComplexItem(masterController, flyView, kmlOrShpFile);
    } else if (complexItemType == StructureScanComplexItem::canonicalName || complexItemType == StructureScanComplexItem::jsonComplexItemTypeValue) {
        return new StructureScanComplexItem(masterController, flyView, kmlOrShpFile);
    } else if (complexItemType == FixedWingLandingComplexItem::canonicalName || complexItemType == FixedWingLandingComplexItem::jsonComplexItemTypeValue) {
        return new FixedWingLandingComplexItem(masterController, flyView);
    } else if (complexItemType == VTOLLandingComplexItem::canonicalName || complexItemType == VTOLLandingComplexItem::jsonComplexItemTypeValue) {
        return new VTOLLandingComplexItem(masterController, flyView);
    }

    qCWarning(QGCCorePluginLog) << "QGCCorePlugin::createComplexMissionItem - Unknown complex item type:" << complexItemType;
    return nullptr;
}
