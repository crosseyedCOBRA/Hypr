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
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): every row's label
// Text is now NText (consistent typography off Style.qml's tokens instead
// of a hardcoded font.pixelSize: 12). The individual module components
// (KernelVersion, CpuLoad, etc.) are untouched here - each is its own file
// with its own styling, out of scope for this pass.
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

                NText { text: "Kernel"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                KernelVersion {
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("cpu", OverflowState.panel)

                NText { text: "CPU"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                CpuLoad {
                    textColor: Colors.coral
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("cpuTemp", OverflowState.panel)

                NText { text: "CPU Temp"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                HwmonSensor {
                    sensorLabel: "Tctl"
                    iconGlyph: ""
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("gpuTemp", OverflowState.panel)

                NText { text: "GPU Temp"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                HwmonSensor {
                    sensorLabel: "edge"
                    iconGlyph: ""
                    textColor: Colors.teal
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("network", OverflowState.panel)

                NText { text: "Network"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                NetworkStatus {
                    textColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("volume", OverflowState.panel)

                NText { text: "Volume"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                VolumeControl {
                    textColor: Colors.purple
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("stayAwake", OverflowState.panel)

                NText { text: "Stay Awake"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                StayAwake {
                    textColor: Colors.textMuted
                    activeColor: Colors.coral
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("nightLight", OverflowState.panel)

                NText { text: "Night Light"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                NightLight {
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("bluetooth", OverflowState.panel)

                NText { text: "Bluetooth"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

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

                NText { text: "Media"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                MediaWidget {
                    textColor: Colors.textMuted
                    activeColor: Colors.teal
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("clipboard", OverflowState.panel)

                NText { text: "Clipboard"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                ClipboardIndicator {
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("wallpaper", OverflowState.panel)

                NText { text: "Wallpaper"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                WallpaperIndicator {
                    textColor: Colors.textMuted
                    activeColor: Colors.teal
                }
            }

            Row {
                spacing: 10
                visible: ModulesConfig.showInTray("battery", OverflowState.panel) && BatteryService.batteryPresent

                NText { text: "Battery"; width: overflowWindow.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                BatteryIndicator {
                    textColor: Colors.textMuted
                }
            }
        }
    }
}
