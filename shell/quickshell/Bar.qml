import QtQuick
import Quickshell

// One panel per monitor. Systray/kernel/network are only shown on the
// primary monitor -- no point duplicating that info across every screen.
//
// Mirrored outputs (e.g. `xrandr --output HDMI-A-0 --same-as DisplayPort-0`)
// still show up as two distinct entries in Quickshell.screens, each with
// identical geometry - without deduplicating them here, a second, fully
// overlapping bar gets created on top of the real one for every mirrored
// screen, hiding its tray/kernel modules behind whichever bar happens to
// stack on top. Collapsing to one bar per unique geometry, keeping the
// first occurrence of each, fixes this while leaving true multi-monitor
// (distinct positions) completely unaffected - and keeps `isPrimary` below
// correct too, since the survivor for the first geometry is always the
// literal `Quickshell.screens[0]` object.
Variants {
    model: {
        const seen = []
        const result = []
        for (const s of Quickshell.screens) {
            const key = s.x + "," + s.y + "," + s.width + "," + s.height
            if (seen.includes(key))
                continue
            seen.push(key)
            result.push(s)
        }
        return result
    }

    PanelWindow {
        id: panel
        required property var modelData
        readonly property bool isPrimary: modelData === Quickshell.screens[0]

        screen: modelData

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitHeight: 44
        exclusiveZone: 44
        color: "transparent"

        // No margin/radius here - the WM now shape-masks dock-type windows
        // for real rounding (see applyShapeToWindow in windowManager.cpp),
        // so this fills the window's actual shape edge to edge (a full-width
        // bar with just its four corners rounded) rather than approximating
        // rounding with its own inset+radius, which (with no compositor to
        // blend alpha) rendered as an opaque black square peeking out around
        // the edges instead of true transparency.
        Rectangle {
            id: barSurface
            anchors.fill: parent
            color: Qt.rgba(0x0c / 255, 0x0b / 255, 0x1a / 255, 0.75) // Colors.bg @ ~bf alpha

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // --- left: logo + workspaces ---
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Image {
                        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/artix.svg"
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: LauncherState.visible = !LauncherState.visible
                        }
                    }

                    Workspaces {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // --- center: clock ---
                NText {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "dddd MMMM d yyyy HH:mm")
                    color: Colors.text
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold

                    SystemClock {
                        id: clock
                        precision: SystemClock.Minutes
                    }

                    // Opens CalendarFlyout.qml anchored below this clock -
                    // one shared flyout instance retargeted to whichever
                    // monitor's clock was actually clicked, see
                    // CalendarFlyoutState.qml.
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (CalendarFlyoutState.targetItem === clockText)
                                CalendarFlyoutState.visible = !CalendarFlyoutState.visible
                            else {
                                CalendarFlyoutState.targetItem = clockText
                                CalendarFlyoutState.visible = true
                            }
                        }
                    }
                }

                // --- right: system status ---
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    SystemTrayRow {
                        window: panel
                        visible: panel.isPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    KernelVersion {
                        visible: ModulesConfig.showInBar("kernel", panel)
                        textColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    CpuLoad {
                        visible: ModulesConfig.showInBar("cpu", panel)
                        textColor: Colors.coral
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HwmonSensor {
                        visible: ModulesConfig.showInBar("cpuTemp", panel)
                        sensorLabel: "Tctl" // k10temp CPU die sensor -- verify with
                                             // `grep . /sys/class/hwmon/hwmon*/temp*_label`
                                             // and adjust if different
                        iconGlyph: "\uf2c9"
                        textColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    HwmonSensor {
                        visible: ModulesConfig.showInBar("gpuTemp", panel)
                        sensorLabel: "edge" // amdgpu GPU sensor -- same caveat as above
                        iconGlyph: "\uf2c9"
                        textColor: Colors.teal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NetworkStatus {
                        visible: ModulesConfig.showInBar("network", panel)
                        textColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ClipboardIndicator {
                        visible: ModulesConfig.showInBar("clipboard", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NotificationIndicator {
                        visible: ModulesConfig.showInBar("notifications", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.purple
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    WallpaperIndicator {
                        visible: ModulesConfig.showInBar("wallpaper", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.teal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BatteryIndicator {
                        visible: ModulesConfig.showInBar("battery", panel) && BatteryService.batteryPresent
                        textColor: Colors.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    VolumeControl {
                        // Deliberately not gated by ModulesConfig.showInBar
                        // ("volume", ...) - see VolumeControl.qml's own
                        // header comment. Falls back to its own internal
                        // `visible: sink && sink.ready` binding.
                        textColor: Colors.purple
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StayAwake {
                        visible: ModulesConfig.showInBar("stayAwake", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.coral
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NightLight {
                        visible: ModulesConfig.showInBar("nightLight", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Dnd {
                        visible: ModulesConfig.showInBar("dnd", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.red
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BluetoothIndicator {
                        visible: ModulesConfig.showInBar("bluetooth", panel)
                        textColor: Colors.textMuted
                        activeColor: Colors.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Image {
                        // Control Center launcher - used to be a "..."
                        // chevron hidden whenever nothing was tray-enabled
                        // (back when Control Center was just the old flat
                        // hidden-tray flyout). Now always visible: the
                        // panel always has real content regardless of any
                        // one module's tray setting (the profile header,
                        // toggle grid, quick-launch tiles, and audio
                        // section aren't tray-gated at all).
                        //
                        // The source asset itself is 347x304, not truly
                        // square - `PreserveAspectFit` into a square box
                        // was letterboxing it (real empty space top and
                        // bottom, not a distortion), reading as "smushed"
                        // next to the bar's other icons. `PreserveAspectCrop`
                        // fills the box completely instead, cropping a
                        // sliver off the wider left/right edges rather than
                        // leaving vertical gaps - a truer square. Sized up
                        // slightly too (20->26) per the same feedback.
                        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/zaris-logo-square.png"
                        width: 26
                        height: 26
                        fillMode: Image.PreserveAspectCrop
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                ControlCenterState.panel = panel
                                // barSurface (the full-width bar background,
                                // not this icon) is what Settings.qml
                                // anchors under - centering it under the
                                // whole bar rather than off to one side.
                                ControlCenterState.barItem = barSurface
                                ControlCenterState.visible = !ControlCenterState.visible
                            }
                        }
                    }
                }
            }
        }
    }
}
