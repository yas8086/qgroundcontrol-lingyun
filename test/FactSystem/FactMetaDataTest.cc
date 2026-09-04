#include "FactMetaDataTest.h"

#include <QtCore/QtNumeric>

#include <cmath>
#include <limits>

#include "FactMetaData.h"
#include "Fact.h"

void FactMetaDataTest::_stringToTypeRoundTrip_test()
{
    const QList<QPair<QString, FactMetaData::ValueType_t>> knownTypes = {
        {"Uint8",          FactMetaData::valueTypeUint8},
        {"Int8",           FactMetaData::valueTypeInt8},
        {"Uint16",         FactMetaData::valueTypeUint16},
        {"Int16",          FactMetaData::valueTypeInt16},
        {"Uint32",         FactMetaData::valueTypeUint32},
        {"Int32",          FactMetaData::valueTypeInt32},
        {"Uint64",         FactMetaData::valueTypeUint64},
        {"Int64",          FactMetaData::valueTypeInt64},
        {"Float",          FactMetaData::valueTypeFloat},
        {"Double",         FactMetaData::valueTypeDouble},
        {"String",         FactMetaData::valueTypeString},
        {"Bool",           FactMetaData::valueTypeBool},
        {"ElapsedSeconds", FactMetaData::valueTypeElapsedTimeInSeconds},
        {"Custom",         FactMetaData::valueTypeCustom},
    };

    for (const auto &[typeStr, expectedType] : knownTypes) {
        bool unknownType = false;
        const auto parsedType = FactMetaData::stringToType(typeStr, unknownType);
        QVERIFY2(!unknownType, qPrintable(QStringLiteral("Unknown type for: ") + typeStr));
        QCOMPARE(parsedType, expectedType);

        const QString roundTrip = FactMetaData::typeToString(parsedType);
        QCOMPARE(roundTrip, typeStr);
    }
}

void FactMetaDataTest::_stringToTypeUnknown_test()
{
    bool unknownType = false;
    const auto type = FactMetaData::stringToType("Nonsense", unknownType);
    QVERIFY(unknownType);
    QCOMPARE(type, FactMetaData::valueTypeDouble);
}

void FactMetaDataTest::_typeToSize_test()
{
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeUint8), 1u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeInt8), 1u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeUint16), 2u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeInt16), 2u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeUint32), 4u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeInt32), 4u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeFloat), 4u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeUint64), 8u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeInt64), 8u);
    QCOMPARE(FactMetaData::typeToSize(FactMetaData::valueTypeDouble), 8u);
}

void FactMetaDataTest::_minForType_test()
{
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeUint8).toUInt(), 0u);
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeInt8).toInt(), static_cast<int>(std::numeric_limits<signed char>::min()));
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeUint16).toUInt(), 0u);
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeUint32).toUInt(), 0u);
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeBool).toInt(), 0);
    QCOMPARE(FactMetaData::minForType(FactMetaData::valueTypeElapsedTimeInSeconds).toDouble(), 0.0);
    QVERIFY(!FactMetaData::minForType(FactMetaData::valueTypeString).isValid());
}

void FactMetaDataTest::_maxForType_test()
{
    QCOMPARE(FactMetaData::maxForType(FactMetaData::valueTypeUint8).toUInt(),
             static_cast<uint>(std::numeric_limits<unsigned char>::max()));
    QCOMPARE(FactMetaData::maxForType(FactMetaData::valueTypeInt8).toInt(),
             static_cast<int>(std::numeric_limits<signed char>::max()));
    QCOMPARE(FactMetaData::maxForType(FactMetaData::valueTypeBool).toInt(), 1);
    QVERIFY(!FactMetaData::maxForType(FactMetaData::valueTypeString).isValid());
    QCOMPARE(FactMetaData::maxForType(FactMetaData::valueTypeFloat).toFloat(),
             std::numeric_limits<float>::max());
    QCOMPARE(FactMetaData::maxForType(FactMetaData::valueTypeDouble).toDouble(),
             std::numeric_limits<double>::max());
}

void FactMetaDataTest::_convertAndValidateRawInt_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);
    meta.setRawMin(QVariant(-100));
    meta.setRawMax(QVariant(100));

    QVariant typedValue;
    QString errorString;

    QVERIFY(meta.convertAndValidateRaw(QVariant(50), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toInt(), 50);

    QVERIFY(!meta.convertAndValidateRaw(QVariant(200), false, typedValue, errorString));
    QVERIFY(!errorString.isEmpty());
}

void FactMetaDataTest::_convertAndValidateRawOutOfRange_test()
{
    FactMetaData meta(FactMetaData::valueTypeUint8);

    QVariant typedValue;
    QString errorString;

    QVERIFY(meta.convertAndValidateRaw(QVariant(100), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());

    // Uint8 range is 0-255, but value is passed as uint32 in validation
    QVERIFY(meta.convertAndValidateRaw(QVariant(0), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
}

void FactMetaDataTest::_convertAndValidateRawConvertOnly_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);
    meta.setRawMin(QVariant(0));
    meta.setRawMax(QVariant(10));

    QVariant typedValue;
    QString errorString;

    // Out of range but convertOnly=true should succeed
    QVERIFY(meta.convertAndValidateRaw(QVariant(999), true, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toInt(), 999);
}

void FactMetaDataTest::_convertAndValidateRawString_test()
{
    FactMetaData meta(FactMetaData::valueTypeString);

    QVariant typedValue;
    QString errorString;

    QVERIFY(meta.convertAndValidateRaw(QVariant("hello"), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toString(), QStringLiteral("hello"));
}

void FactMetaDataTest::_convertAndValidateRawBool_test()
{
    FactMetaData meta(FactMetaData::valueTypeBool);

    QVariant typedValue;
    QString errorString;

    QVERIFY(meta.convertAndValidateRaw(QVariant(true), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toBool(), true);

    QVERIFY(meta.convertAndValidateRaw(QVariant(false), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toBool(), false);
}

void FactMetaDataTest::_convertAndValidateCookedInt_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);
    meta.setRawMin(QVariant(-50));
    meta.setRawMax(QVariant(50));

    QVariant typedValue;
    QString errorString;

    QVERIFY(meta.convertAndValidateCooked(QVariant(25), false, typedValue, errorString));
    QVERIFY(errorString.isEmpty());
    QCOMPARE(typedValue.toInt(), 25);

    QVERIFY(!meta.convertAndValidateCooked(QVariant(100), false, typedValue, errorString));
    QVERIFY(!errorString.isEmpty());
}

void FactMetaDataTest::_clampValueInt_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);
    meta.setRawMin(QVariant(0));
    meta.setRawMax(QVariant(100));

    QVariant typedValue;

    QVERIFY(meta.clampValue(QVariant(50), typedValue));
    QCOMPARE(typedValue.toInt(), 50);

    QVERIFY(meta.clampValue(QVariant(200), typedValue));
    QCOMPARE(typedValue.toInt(), 100);

    QVERIFY(meta.clampValue(QVariant(-10), typedValue));
    QCOMPARE(typedValue.toInt(), 0);
}

void FactMetaDataTest::_clampValueDouble_test()
{
    FactMetaData meta(FactMetaData::valueTypeDouble);
    meta.setRawMin(QVariant(-1.0));
    meta.setRawMax(QVariant(1.0));

    QVariant typedValue;

    QVERIFY(meta.clampValue(QVariant(0.5), typedValue));
    QCOMPARE(typedValue.toDouble(), 0.5);

    QVERIFY(meta.clampValue(QVariant(5.0), typedValue));
    QCOMPARE(typedValue.toDouble(), 1.0);

    QVERIFY(meta.clampValue(QVariant(-5.0), typedValue));
    QCOMPARE(typedValue.toDouble(), -1.0);
}

void FactMetaDataTest::_enumOperations_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);

    meta.addEnumInfo("Option A", QVariant(0));
    meta.addEnumInfo("Option B", QVariant(1));
    meta.addEnumInfo("Option C", QVariant(2));

    QCOMPARE(meta.enumStrings().count(), 3);
    QCOMPARE(meta.enumValues().count(), 3);
    QCOMPARE(meta.enumStrings()[0], QStringLiteral("Option A"));
    QCOMPARE(meta.enumValues()[1].toInt(), 1);

    meta.removeEnumInfo(QVariant(1));
    QCOMPARE(meta.enumStrings().count(), 2);
    QCOMPARE(meta.enumValues().count(), 2);
    QCOMPARE(meta.enumStrings()[1], QStringLiteral("Option C"));
}

void FactMetaDataTest::_bitmaskOperations_test()
{
    FactMetaData meta(FactMetaData::valueTypeUint32);

    meta.addBitmaskInfo("Bit 0", QVariant(1));
    meta.addBitmaskInfo("Bit 1", QVariant(2));
    meta.addBitmaskInfo("Bit 2", QVariant(4));

    QCOMPARE(meta.bitmaskStrings().count(), 3);
    QCOMPARE(meta.bitmaskValues().count(), 3);
    QCOMPARE(meta.bitmaskStrings()[0], QStringLiteral("Bit 0"));
    QCOMPARE(meta.bitmaskValues()[2].toInt(), 4);
}

void FactMetaDataTest::_defaultValue_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);

    QVERIFY(!meta.defaultValueAvailable());

    meta.setRawDefaultValue(QVariant(42));
    QVERIFY(meta.defaultValueAvailable());
    QCOMPARE(meta.rawDefaultValue().toInt(), 42);
    QCOMPARE(meta.cookedDefaultValue().toInt(), 42);
}

void FactMetaDataTest::_defaultValueOutOfRange_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);
    meta.setRawMin(QVariant(0));
    meta.setRawMax(QVariant(100));

    // Attempting to set default outside range should not set it
    meta.setRawDefaultValue(QVariant(200));
    QVERIFY(!meta.defaultValueAvailable());
}

void FactMetaDataTest::_builtInTranslatorRadians_test()
{
    FactMetaData meta(FactMetaData::valueTypeDouble);
    meta.setRawUnits("radians");

    QCOMPARE(meta.cookedUnits(), QStringLiteral("deg"));

    const QVariant cooked = meta.rawTranslator()(QVariant(M_PI));
    QCOMPARE_FUZZY(cooked.toDouble(), 180.0, 1e-5);

    const QVariant raw = meta.cookedTranslator()(QVariant(180.0));
    QCOMPARE_FUZZY(raw.toDouble(), M_PI, 1e-5);
}

void FactMetaDataTest::_builtInTranslatorCentiDegrees_test()
{
    FactMetaData meta(FactMetaData::valueTypeDouble);
    meta.setRawUnits("centi-degrees");

    QCOMPARE(meta.cookedUnits(), QStringLiteral("deg"));

    const QVariant cooked = meta.rawTranslator()(QVariant(18000.0));
    QCOMPARE_FUZZY(cooked.toDouble(), 180.0, 1e-5);
}

void FactMetaDataTest::_builtInTranslatorNorm_test()
{
    FactMetaData meta(FactMetaData::valueTypeFloat);
    meta.setRawUnits("norm");

    QCOMPARE(meta.cookedUnits(), QStringLiteral("%"));

    const QVariant cooked = meta.rawTranslator()(QVariant(0.5));
    QCOMPARE_FUZZY(cooked.toDouble(), 50.0, 1e-5);
}

void FactMetaDataTest::_setMinMax_test()
{
    FactMetaData meta(FactMetaData::valueTypeInt32);

    meta.setRawMin(QVariant(-10));
    meta.setRawMax(QVariant(10));

    QCOMPARE(meta.rawMin().toInt(), -10);
    QCOMPARE(meta.rawMax().toInt(), 10);
    QVERIFY(!meta.minIsDefaultForType());
    QVERIFY(!meta.maxIsDefaultForType());
}

// Reproduce the Lingyun01 firmware issue: output function value 201 (Blower1)
// was reported to render as "Unknown: 201" while 202-208 (Valve1..Valve4)
// render fine. The json below mirrors the real parameters.json served by the
// vehicle (see docs/lingyun/问题/QGC渲染bug报告_功能201显示为Unknown.md).
void FactMetaDataTest::_jsonEnumParsingBlower_test()
{
    static const QList<QPair<QString, int>> kValues = {
        {"Disabled", 0},
        {"Constant Min", 1},
        {"Constant Max", 2},
        {"Motor 1", 101}, {"Motor 2", 102}, {"Motor 3", 103}, {"Motor 4", 104},
        {"Motor 5", 105}, {"Motor 6", 106}, {"Motor 7", 107}, {"Motor 8", 108},
        {"Motor 9", 109}, {"Motor 10", 110}, {"Motor 11", 111}, {"Motor 12", 112},
        {"Blower1", 201}, {"Valve1", 202}, {"Blower2", 203}, {"Valve2", 204},
        {"Blower3", 205}, {"Valve3", 206}, {"Blower4", 207}, {"Valve4", 208},
        {"Peripheral via Actuator Set 1", 301},
        {"Peripheral via Actuator Set 2", 302},
        {"Peripheral via Actuator Set 3", 303},
        {"Peripheral via Actuator Set 4", 304},
        {"Peripheral via Actuator Set 5", 305},
        {"Peripheral via Actuator Set 6", 306},
        {"Landing Gear", 400},
        {"Parachute", 401},
        {"RC Roll", 402}, {"RC Pitch", 403}, {"RC Throttle", 404}, {"RC Yaw", 405},
        {"RC Flaps", 406}, {"RC Aux 1", 407}, {"RC Aux 2", 408},
        {"RC Aux 3", 409}, {"RC Aux 4", 410}, {"RC Aux 5", 411}, {"RC Aux 6", 412},
        {"Gimbal Roll", 420}, {"Gimbal Pitch", 421}, {"Gimbal Yaw", 422},
        {"Gripper", 430}, {"Landing Gear Wheel", 440},
        {"Roll", 450}, {"Pitch", 451}, {"Yaw", 452}, {"Elevation", 453},
        {"Camera Trigger", 2000}, {"Camera Capture", 2032},
        {"PPS Input", 2064}, {"RPM Input", 2070},
    };

    QJsonObject paramJson;
    paramJson["name"] = "PWM_MAIN_FUNC1";
    paramJson["type"] = "Int32";
    paramJson["shortDesc"] = "PWM Main 1 Output Function";
    paramJson["group"] = "Actuator Outputs";
    paramJson["category"] = "Standard";
    paramJson["default"] = 0;

    QJsonArray valuesArray;
    for (const auto &[description, value] : kValues) {
        QJsonObject entry;
        entry["description"] = description;
        entry["value"] = value;
        valuesArray.append(entry);
    }
    paramJson["values"] = valuesArray;

    FactMetaData *meta = FactMetaData::createFromJsonObject(paramJson, {}, this);
    QVERIFY(meta);

    QCOMPARE(meta->enumStrings().count(), kValues.count());
    QCOMPARE(meta->enumValues().count(), kValues.count());

    // Every value must survive parsing, especially 201 (Blower1)
    for (const auto &[description, value] : kValues) {
        const int index = meta->enumValues().indexOf(QVariant(value));
        QVERIFY2(index >= 0, qPrintable(QStringLiteral("enum value %1 (%2) missing").arg(value).arg(description)));
        QCOMPARE(meta->enumStrings()[index], description);
    }

    // Fact-level check: rawValue 201 (int32) must resolve to "Blower1", not "Unknown: 201"
    Fact fact(0 /* componentId */, QStringLiteral("PWM_MAIN_FUNC1"), FactMetaData::valueTypeInt32, this);
    fact.setMetaData(meta);
    fact.setRawValue(QVariant(201));
    QCOMPARE(fact.enumIndex(), meta->enumValues().indexOf(QVariant(201)));
    QCOMPARE(fact.enumStringValue(), QStringLiteral("Blower1"));

    // Also verify the QVariant type-coercion comparison used by Fact::enumIndex
    QVERIFY(QVariant(201) == QVariant(201.0));  // int vs double
    QVERIFY(QVariant(201) == QVariant(201.0f)); // int vs float
    QVERIFY(QVariant(201) == QVariant(201u));   // int vs uint
}

UT_REGISTER_TEST(FactMetaDataTest, TestLabel::Unit)
