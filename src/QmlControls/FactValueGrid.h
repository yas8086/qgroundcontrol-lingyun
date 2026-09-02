#pragma once

#include <QtCore/QSettings>
#include <QtQuick/QQuickItem>
#include <QtQmlIntegration/QtQmlIntegration>

#include "QGCMAVLinkTypes.h"

class InstrumentValueData;
class QmlObjectListModel;
class Vehicle;

class FactValueGrid : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
    Q_MOC_INCLUDE("QmlObjectListModel.h")
public:
    FactValueGrid(QQuickItem *parent = nullptr);
    ~FactValueGrid();

    enum FontSize {
        DefaultFontSize=0,
        SmallFontSize,
        MediumFontSize,
        LargeFontSize,
    };
    Q_ENUM(FontSize)

    Q_PROPERTY(QmlObjectListModel*  columns         MEMBER _columns                                     NOTIFY columnsChanged)
    Q_PROPERTY(int                  rowCount        MEMBER _rowCount                                    NOTIFY rowCountChanged)
    Q_PROPERTY(QStringList          iconNames       READ iconNames                                      CONSTANT)
    Q_PROPERTY(FontSize             fontSize        READ fontSize           WRITE setFontSize           NOTIFY fontSizeChanged)
    Q_PROPERTY(QStringList          fontSizeNames   MEMBER _fontSizeNames                               CONSTANT)

    // The following properties should only be set at initial object creation time
    // settingsGroup uses a WRITE setter because when assigned through chained QML
    // aliases (e.g. AirshipPagedValuesBar -> TelemetryValuesBar -> grid) the value
    // arrives after componentComplete, so the setter re-runs _resetFromSettings.
    Q_PROPERTY(QString              settingsGroup           READ settingsGroup      WRITE setSettingsGroup  NOTIFY settingsGroupChanged             REQUIRED)
    Q_PROPERTY(Vehicle *            specificVehicleForCard  MEMBER _specificVehicleForCard  NOTIFY specificVehicleForCardChanged    REQUIRED)   ///< null means track active vehicle, set to specific vehicle to track a single vehicle and share settings with other cards
    /// If true, newly appended value slots start empty (cleared) instead of being pre-filled with AltitudeRelative
    Q_PROPERTY(bool                 emptyNewValues          MEMBER _emptyNewValues          NOTIFY emptyNewValuesChanged)
    /// Hard limits on grid size (0 = unlimited). Enforced inside appendColumn/appendRow
    /// so both user edits and plugin default injection respect them.
    Q_PROPERTY(int                  maxColumns              MEMBER _maxColumns              NOTIFY maxColumnsChanged)
    Q_PROPERTY(int                  maxRows                 MEMBER _maxRows                 NOTIFY maxRowsChanged)

    Q_INVOKABLE void                resetToDefaults (void);
    Q_INVOKABLE QmlObjectListModel* appendColumn    (void);
    Q_INVOKABLE void                deleteLastColumn(void);
    Q_INVOKABLE void                appendRow       (void);
    Q_INVOKABLE void                deleteLastRow   (void);

    QmlObjectListModel*         columns                 (void) const { return _columns; }
    QString                     settingsGroup           (void) const { return _settingsGroup; }
    void                        setSettingsGroup        (const QString& settingsGroup);
    void                        setMaxColumns           (int maxColumns) { if (_maxColumns != maxColumns) { _maxColumns = maxColumns; emit maxColumnsChanged(_maxColumns); } }
    void                        setMaxRows              (int maxRows) { if (_maxRows != maxRows) { _maxRows = maxRows; emit maxRowsChanged(_maxRows); } }
    FontSize                    fontSize                (void) const { return _fontSize; }
    QStringList                 iconNames               (void) const { return _iconNames; }
    QGCMAVLinkTypes::VehicleClass_t  vehicleClass            (void) const;
    Vehicle*                    currentVehicle          (void) const { return _specificVehicleForCard ? _specificVehicleForCard : _activeVehicle; }
    Vehicle*                    specificVehicleForCard  (void) const { return _specificVehicleForCard; }

    void setFontSize(FontSize fontSize);

    // Override from QQmlParserStatus
    void componentComplete(void) final;

signals:
    void fontSizeChanged(FontSize fontSize);
    void columnsChanged (QmlObjectListModel* model);
    void rowCountChanged(int rowCount);
    void settingsGroupChanged(QString settingsGroup);
    void specificVehicleForCardChanged(Vehicle* vehicle);
    void emptyNewValuesChanged(bool emptyNewValues);
    void maxColumnsChanged(int maxColumns);
    void maxRowsChanged(int maxRows);

protected:
    Q_DISABLE_COPY(FactValueGrid)

    QString                     _settingsGroup;
    FontSize                    _fontSize               = DefaultFontSize;
    bool                        _preventSaveSettings    = false;
    bool                        _emptyNewValues         = false;
    bool                        _componentComplete      = false;
    int                         _maxColumns             = 0;
    int                         _maxRows                = 0;
    QmlObjectListModel*         _columns                = nullptr;
    int                         _rowCount               = 0;
    Vehicle*                    _specificVehicleForCard = nullptr;
    Vehicle*                    _activeVehicle          = nullptr;

private slots:
    void _activeVehicleChanged(Vehicle *activeVehicle);
    void _resetFromSettings(void);

private:
    InstrumentValueData*    _createNewInstrumentValueWorker (QObject* parent);
    void                    _saveSettings                   (void);
    void                    _connectSaveSignals             (InstrumentValueData* value);
    QString                 _pascalCase                     (const QString& text);
    void                    _saveValueData                  (QSettings& settings, InstrumentValueData* value);
    void                    _loadValueData                  (QSettings& settings, InstrumentValueData* value);
    QString                 _settingsKey                    (void);
    void                    _initForNewVehicle              (Vehicle* vehicle);
    void                    _deinitVehicle                  (Vehicle* vehicle);

    // These are user facing string for the various enums.
    static       QStringList _iconNames;
    QStringList _fontSizeNames;

    static constexpr const char* _columnsKey          = "columns";
    static constexpr const char* _rowsKey             = "rows";
    static constexpr const char* _rowCountKey         = "rowCount";
    static constexpr const char* _fontSizeKey         = "fontSize";
    static constexpr const char* _versionKey          = "version";
    static constexpr const char* _factGroupNameKey    = "factGroupName";
    static constexpr const char* _factNameKey         = "factName";
    static constexpr const char* _textKey             = "text";
    static constexpr const char* _showUnitsKey        = "showUnits";
    static constexpr const char* _iconKey             = "icon";
    static constexpr const char* _rangeTypeKey        = "rangeType";
    static constexpr const char* _rangeValuesKey      = "rangeValues";
    static constexpr const char* _rangeColorsKey      = "rangeColors";
    static constexpr const char* _rangeIconsKey       = "rangeIcons";
    static constexpr const char* _rangeOpacitiesKey   = "rangeOpacities";

    static constexpr const char* _deprecatedGroupKey =  "ValuesWidget";

    static QList<FactValueGrid*> _vehicleCardInstanceList;
};

QML_DECLARE_TYPE(FactValueGrid)
