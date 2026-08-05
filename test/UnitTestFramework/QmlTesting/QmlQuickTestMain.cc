#include <QtQuickTest/quicktest.h>

// C1 现状说明（架构约束，非简单 bug）：
//
// QGCQmlQuickTests 是独立可执行文件，通过 quick_test_main() 执行 tst_*.qml。
// 飞艇 QML 测试依赖 QGroundControl singleton（QGroundControlQmlGlobal），而该
// singleton 的构造会调用 12+ 个 QGC 单例的 instance()（SettingsManager、
// LinkManager、MultiVehicleManager、QGCCorePlugin、GPSManager->gpsRtk()->gpsRtkFactGroup()
// 等），这些单例仅在 QGCApplication::init() 中被创建/初始化。
//
// 但 QGCApplication.cc、QGCCommandLineParser.cc、Platform.cc 都是主项目
// （${CMAKE_PROJECT_NAME}）的 PRIVATE target_sources，不属于任何可链接的库，
// QGCQmlQuickTests 无法链接到这些符号。要让测试初始化完整 QGCApplication，
// 需展开 ~15 个 QGC 模块库的依赖链（属架构级重构），代价远超"修复测试假绿"
// 的收益，且 QGCApplication::init() 的 _initForNormalAppBoot() 会创建 QML 引擎
// 与 root window，与 quick_test_main 自身的 QML 引擎冲突。
//
// 因此 QGCQmlQuickTests 保持轻量，飞艇测试用 skip guard 守护；依赖完整 QGC
// 环境的逻辑改由 QGC C++ 单元测试框架（QGC_UNITTEST_BUILD 路径下完整初始化
// QGCApplication）承载，避免 CI 假绿。详见 .trae/documents/airship-p0-fixes.md
// Task 4 的"降级方案"。

QUICK_TEST_MAIN(QGCQmlQuickTests)
