#pragma once

#include "UnitTest.h"

/// C++ 单元测试：验证飞艇 FlyViewSettings 的默认值与读写。
///
/// 背景（C1 降级方案）：
///   QGCQmlQuickTests（独立 QML 测试进程）无法初始化完整 QGCApplication
///   —— QGCApplication.cc / QGCCommandLineParser.cc / Platform.cc 都是主项目
///   ${CMAKE_PROJECT_NAME} 的 PRIVATE target_sources，不属于任何可链接库，
///   且 QGroundControlQmlGlobal 构造调用 12+ 个 QGC 单例的 instance()，
///   仅在 QGCApplication::init() 中初始化。彻底修复需架构级重构（提取
///   QGCApplication 成独立库 + 展开 ~15 个模块库依赖 + 处理 QML 引擎冲突），
///   代价远超"修复测试假绿"的收益。
///
///   因此飞艇 settings 默认值验证从 tst_AirshipSettings.qml（skip 守卫）迁移到
///   本 C++ 测试。QGC C++ 单元测试框架在 QGC_UNITTEST_BUILD 路径下由 main.cc
///   初始化完整 QGCApplication，SettingsManager 已就绪，可真正执行断言，
///   避免 CI 假绿。QML 侧的分页钳制/增删页等 UI 逻辑验证延后至端到端 GUI 实测。
class AirshipSettingsTest : public UnitTest
{
    Q_OBJECT

private slots:
    void _airshipInstrumentPageCount_default_test();
    void _airshipShowTelemetryBar_default_test();
    void _airshipInstrumentPageCount_readWrite_test();
    void _airshipShowTelemetryBar_readWrite_test();
    // P0 幽灵配置回归：resetToDefaults() 必须删除带 vehicleClass 后缀的
    // QSettings group（"_settingsKey()"），而非不带后缀的 _settingsGroup。
    void _resetToDefaults_removesVehicleClassGroup_test();
};
