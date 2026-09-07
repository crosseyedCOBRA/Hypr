import QtQuick
import Quickshell

// The "hidden tray" flyout - shows whatever modules.json marks as
// "tray": true for the monitor whose chevron opened it (OverflowState.panel).
// Live state (e.g. StayAwake) is read from the same shared singletons the
// inline bar modules use, so toggling from here or from the bar stays in
// sync - these are just a second view onto the same state, not a separate
// instance of it.
FloatingWindow {
    id: overflowWindow

    visible: OverflowState.visible
    title: "More"

    implicitWidth: Math.max(160, content.implicitWidth + 24)
    implicitHeight: content.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            KernelVersion {
                visible: ModulesConfig.showInTray("kernel", OverflowState.panel)
                textColor: Colors.blue
            }

            CpuLoad {
                visible: ModulesConfig.showInTray("cpu", OverflowState.panel)
                textColor: Colors.coral
            }

            HwmonSensor {
                visible: ModulesConfig.showInTray("cpuTemp", OverflowState.panel)
                sensorLabel: "Tctl"
                iconGlyph: ""
                textColor: Colors.blue
            }

            HwmonSensor {
                visible: ModulesConfig.showInTray("gpuTemp", OverflowState.panel)
                sensorLabel: "edge"
                iconGlyph: ""
                textColor: Colors.teal
            }

            NetworkStatus {
                visible: ModulesConfig.showInTray("network", OverflowState.panel)
                textColor: Colors.blue
            }

            VolumeControl {
                visible: ModulesConfig.showInTray("volume", OverflowState.panel)
                textColor: Colors.purple
            }

            StayAwake {
                visible: ModulesConfig.showInTray("stayAwake", OverflowState.panel)
                textColor: Colors.textMuted
                activeColor: Colors.coral
            }
        }
    }
}
