import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Column {
    property var channel
    property alias value:             channelSlider.value

    // If the default value is NaN, we add a small range
    // below, which snaps into place
    property var snap:                isNaN(channel.defaultValue)
    property var span:                channel.max - channel.min
    property var snapRange:           span * 0.15
    // 灵云01: 滑条默认一律停在最低(channel.min = 控制量-1 = 0us恒低安全位)
    // 原逻辑 defaultVal=channel.defaultValue(0=中间=50%占空), 打开测试开关瞬间会立即输出中间值
    // 贴底(snap 时停在 snap 区底部=from 位置): 视觉上贴滑条最低端, 语义为 NaN=停止,
    // Timer 发 NaN → stopControl + stop() 回位仍在底部, 无弹跳
    property var defaultVal:          snap ? channel.min - snapRange : channel.min
    property var blockUpdates:        true // avoid slider changes on startup

    id:                               root

    Layout.alignment:                 Qt.AlignTop

    readonly property int _sliderHeight: 6

    function stopTimer() {
        sendTimer.stop();
    }

    function stop() {
        channelSlider.value = defaultVal;
        stopTimer();
    }

    signal actuatorValueChanged(real value, real sliderValue)

    QGCSlider {
        id:                         channelSlider
        orientation:                Qt.Vertical
        from:               snap ? channel.min - snapRange : channel.min
        to:               channel.max
        stepSize:                   (channel.max-channel.min)/100
        value:                      defaultVal
        live:   true
        anchors.horizontalCenter:   parent.horizontalCenter
        height:                     ScreenTools.defaultFontPixelHeight * _sliderHeight

        onValueChanged: {
            if (blockUpdates)
                return;
            if (snap) {
                if (value < channel.min) {
                    if (value < channel.min - snapRange/2) {
                        value = channel.min - snapRange;
                    } else {
                        value = channel.min;
                    }
                }
            }
            sendTimer.start()
        }

        Timer {
            id:               sendTimer
            interval:         50
            triggeredOnStart: true
            repeat:           true
            running:          false
            onTriggered:      {
                var sendValue = channelSlider.value;
                if (sendValue < channel.min - snapRange/2) {
                    sendValue = channel.defaultValue;
                }
                root.actuatorValueChanged(sendValue, channelSlider.value)
            }
        }

        Component.onCompleted: {
            blockUpdates = false;
        }
    }

    QGCLabel {
        id: channelLabel
        anchors.horizontalCenter: parent.horizontalCenter
        text:                     channel.label
        width:                    contentHeight
        height:                   contentWidth
        transform: [
            Rotation { origin.x: 0; origin.y: 0; angle: -90 },
            Translate { y: channelLabel.height + 5 }
            ]
    }
} // Column
