import QtQuick
import Quickshell

// The "hidden tray" flyout - shows whatever modules.json marks as
// "tray": true for the monitor whose chevron opened it (OverflowState.panel).
// Live state (e.g. StayAwake) is read from the same shared singletons the
// inline bar modules use, so toggling from here or from the bar stays in
// sync - these are just a second view onto the same state, not a separate
// instance of it.
//
// Each module is wrapped in a label + component Row here (not inside the
// module files themselves, and not in Bar.qml's compact usage) - the bar
// stays icon-only for space, but a flyout list has room to say what each
// row actually is. Wrapping rather than modifying the components also means
// any existing MouseArea inside a module (Volume, StayAwake, NightLight,
// BluetoothIndicator all have real click behavior) is untouched - the label
// is just a sibling Text to its left, never something layered on top of it
// that could shadow its hit region.
FloatingWindow {
    id: overflowWindow

    visible: OverflowState.visible
    title: "More"

    implicitWidth: Math.max(200, content.implicitWidth + 24)
    implicitHeight: content.implicitHeight + 24

    readonly property int labelWidth: 80

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("kernel", OverflowState.panel)

                Text { text: "Kernel"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                KernelVersion {
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("cpu", OverflowState.panel)

                Text { text: "CPU"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                CpuLoad {
                    textColor: Colors.coral
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("cpuTemp", OverflowState.panel)

                Text { text: "CPU Temp"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                HwmonSensor {
                    sensorLabel: "Tctl"
                    iconGlyph: ""
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("gpuTemp", OverflowState.panel)

                Text { text: "GPU Temp"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                HwmonSensor {
                    sensorLabel: "edge"
                    iconGlyph: ""
                    textColor: Colors.teal
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("network", OverflowState.panel)

                Text { text: "Network"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                NetworkStatus {
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("volume", OverflowState.panel)

                Text { text: "Volume"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                VolumeControl {
                    textColor: Colors.purple
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("stayAwake", OverflowState.panel)

                Text { text: "Stay Awake"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                StayAwake {
                    textColor: Colors.textMuted
                    activeColor: Colors.coral
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("nightLight", OverflowState.panel)

                Text { text: "Night Light"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                NightLight {
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("bluetooth", OverflowState.panel)

                Text { text: "Bluetooth"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                BluetoothIndicator {
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                // Also hides when nothing's playing, same reasoning as
                // Bar.qml's instance - a label with nothing next to it
                // would look broken otherwise.
                visible: ModulesConfig.showInTray("mediaPlayer", OverflowState.panel) && !!MediaService.currentPlayer

                Text { text: "Media"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                MediaWidget {
                    textColor: Colors.textMuted
                    activeColor: Colors.teal
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("clipboard", OverflowState.panel)

                Text { text: "Clipboard"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                ClipboardIndicator {
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("wallpaper", OverflowState.panel)

                Text { text: "Wallpaper"; width: overflowWindow.labelWidth; color: Colors.textMuted; font.pixelSize: 12 }

                WallpaperIndicator {
                    textColor: Colors.textMuted
                    activeColor: Colors.teal
                }
            }
        }
    }
}
