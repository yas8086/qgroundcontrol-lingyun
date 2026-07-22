#include "PX4FirmwarePluginFactory.h"
#include "PX4FirmwarePlugin.h"
#include "AirshipFirmwarePlugin.h"

PX4FirmwarePluginFactory PX4FirmwarePluginFactory;

PX4FirmwarePluginFactory::PX4FirmwarePluginFactory(void)
    : _pluginInstance(nullptr)
    , _airshipPluginInstance(nullptr)
{

}

QList<QGCMAVLink::FirmwareClass_t> PX4FirmwarePluginFactory::supportedFirmwareClasses(void) const
{
    QList<QGCMAVLink::FirmwareClass_t> list;
    list.append(QGCMAVLink::FirmwareClassPX4);
    return list;
}

FirmwarePlugin* PX4FirmwarePluginFactory::firmwarePluginForAutopilot(MAV_AUTOPILOT autopilotType, MAV_TYPE vehicleType)
{
    if (autopilotType == MAV_AUTOPILOT_PX4) {
        // 飞艇使用专用的固件插件，处理简化的 custom_mode（0-7）映射
        if (vehicleType == MAV_TYPE_AIRSHIP) {
            if (!_airshipPluginInstance) {
                _airshipPluginInstance = new AirshipFirmwarePlugin();
            }
            return _airshipPluginInstance;
        }

        if (!_pluginInstance) {
            _pluginInstance = new PX4FirmwarePlugin();
        }
        return _pluginInstance;
    }
    return nullptr;
}
