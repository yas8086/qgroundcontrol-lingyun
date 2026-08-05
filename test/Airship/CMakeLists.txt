# ============================================================================
# Airship Unit Tests
# 飞艇二次开发验证：settings 默认值/读写、FactGroup 元数据等
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        AirshipSettingsTest.cc
        AirshipSettingsTest.h
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_qgc_test(AirshipSettingsTest LABELS Unit)
