import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Phase 3 of the Noctalia-port effort (see ROADMAP.md): the "hidden tray"
// flyout, rebuilt as a tabbed Control Center - Home (header actions, quick-
// toggle grid, quick-launch actions, volume, media, battery) and System
// (the original flat info-row list). Not a port of Noctalia v5's own
// Control Center (its code is Wayland/OpenGL-native, nothing to port),
// just the same idea built from Zaris's existing services: a richer, more
// scannable landing spot than one long column of label+widget rows.
// Deliberately skipped two pieces of Noctalia's version that have no Zaris
// equivalent yet: an avatar/large clock (the bar's own clock is already
// visible behind this panel, wherever it's opened from) and weather+
// forecast/power-profile (no weather service or power-profile switching
// exists here - real future features, not folded into this pass).
//
// Second pass: Settings, the power menu, and a close button moved here
// from being bare always-visible Bar.qml icons (a fixed header, visible
// regardless of which tab is active, matching Noctalia's own reference
// screenshot); Clipboard, Wallpaper, and Screenshot got a new Home-tab
// quick-launch icon row (opening the same existing panels/script their old
// bar icons did). Clipboard/Wallpaper/Battery/Dnd's `modules.json` `tray`
// default flipped to `true` at the same time (ModulesConfig.qml), so they
// stop appearing inline in the bar automatically - no Bar.qml changes
// needed for those four, the existing tray mechanism already covers it.
//
// Same "tray": true opt-in from modules.json still gates every module here,
// exactly as it did in the old flat Overflow.qml - this is a presentation
// change, not a new config surface. Live state (StayAwake, NightLight, Dnd,
// Bluetooth, volume, media, battery) is read from the same shared
// singletons/services the bar's inline modules use, so toggling from here
// stays in sync with the bar.
FloatingWindow {
    id: root

    visible: ControlCenterState.visible
    title: "Control Center"

    property int currentTab: 0

    // Fixed size, same reasoning as Settings.qml's fixed 680x460 - a real
    // bug found while building this (not just a Xephyr-sandbox artifact,
    // confirmed via a debug Timer on the LIVE desktop with a real WM
    // running): FloatingWindow's actual OS-level height never tracked
    // content.implicitHeight growing after first map (root.height stayed
    // at 51 while root.implicitHeight correctly read 207 the whole time),
    // even though width tracked implicitWidth closely. Rather than chase
    // whether that's a Quickshell or WM-side (topright's own position/size
    // recompute) limitation, sidestepped it the same way Settings.qml
    // already does for its own Bar/Dock categories of differing height -
    // one fixed size generous enough for the taller Home tab, with the
    // shorter System tab just leaving empty space below.
    implicitWidth: 344
    implicitHeight: 530

    readonly property PwNode pwSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.pwSink ? [root.pwSink] : [] }

    readonly property int labelWidth: 80
    readonly property int tabContentWidth: 320
    readonly property int tileWidth: 150
    readonly property int tileHeight: 64

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            id: content
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 12
            spacing: 12

            Item {
                width: root.tabContentWidth
                height: 26

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Settings"
                        onClicked: SettingsState.visible = !SettingsState.visible
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Power menu"
                        onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/zaris/powermenu.sh"])
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Close"
                        onClicked: ControlCenterState.visible = false
                    }
                }
            }

            NTabBar {
                width: root.tabContentWidth

                NTabButton {
                    text: "Home"
                    checked: root.currentTab === 0
                    onClicked: root.currentTab = 0
                }

                NTabButton {
                    text: "System"
                    checked: root.currentTab === 1
                    onClicked: root.currentTab = 1
                }
            }

            NTabView {
                id: tabView
                width: root.tabContentWidth
                currentIndex: root.currentTab

                // ==================== Home ====================
                Column {
                    width: tabView.width
                    spacing: 14

                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10

                        Rectangle {
                            width: root.tileWidth
                            height: root.tileHeight
                            radius: Style.radiusS
                            color: Colors.pill
                            visible: ModulesConfig.showInTray("stayAwake", ControlCenterState.panel)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                StayAwake {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    textColor: Colors.textMuted
                                    activeColor: Colors.coral
                                }

                                NText {
                                    text: "Stay Awake"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }

                        Rectangle {
                            width: root.tileWidth
                            height: root.tileHeight
                            radius: Style.radiusS
                            color: Colors.pill
                            visible: ModulesConfig.showInTray("nightLight", ControlCenterState.panel)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                NightLight {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    textColor: Colors.textMuted
                                    activeColor: Colors.blue
                                }

                                NText {
                                    text: "Night Light"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }

                        Rectangle {
                            width: root.tileWidth
                            height: root.tileHeight
                            radius: Style.radiusS
                            color: Colors.pill
                            visible: ModulesConfig.showInTray("dnd", ControlCenterState.panel)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Dnd {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    textColor: Colors.textMuted
                                    activeColor: Colors.red
                                }

                                NText {
                                    text: "Do Not Disturb"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }

                        Rectangle {
                            width: root.tileWidth
                            height: root.tileHeight
                            radius: Style.radiusS
                            color: Colors.pill
                            visible: ModulesConfig.showInTray("bluetooth", ControlCenterState.panel)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                BluetoothIndicator {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    textColor: Colors.textMuted
                                    activeColor: Colors.blue
                                }

                                NText {
                                    text: "Bluetooth"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 10

                        NIconButton {
                            baseSize: 30
                            icon: ""
                            tooltipText: "Clipboard History"
                            visible: ModulesConfig.showInTray("clipboard", ControlCenterState.panel)
                            onClicked: ClipboardHistoryPanelState.visible = !ClipboardHistoryPanelState.visible
                        }

                        NIconButton {
                            baseSize: 30
                            icon: ""
                            tooltipText: "Wallpaper Picker"
                            visible: ModulesConfig.showInTray("wallpaper", ControlCenterState.panel)
                            onClicked: WallpaperPickerPanelState.visible = !WallpaperPickerPanelState.visible
                        }

                        NIconButton {
                            baseSize: 30
                            icon: ""
                            tooltipText: "Screenshot (right-click: full)"
                            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/zaris/screenshot.sh"])
                            onRightClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/zaris/screenshot.sh", "full"])
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        visible: ModulesConfig.showInTray("volume", ControlCenterState.panel) && !!root.pwSink && root.pwSink.ready

                        NIconButton {
                            baseSize: 26
                            icon: (root.pwSink && root.pwSink.ready && root.pwSink.audio.muted) ? "󰖁" : ""
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (root.pwSink)
                                    root.pwSink.audio.muted = !root.pwSink.audio.muted
                            }
                        }

                        NSlider {
                            width: parent.width - 26 - 40 - parent.spacing * 2
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1.0
                            value: root.pwSink && root.pwSink.ready ? root.pwSink.audio.volume : 0
                            onMoved: {
                                if (root.pwSink)
                                    root.pwSink.audio.volume = value
                            }
                        }

                        NText {
                            text: root.pwSink && root.pwSink.ready ? Math.round(root.pwSink.audio.volume * 100) + "%" : ""
                            width: 40
                            color: Colors.textMuted
                            pointSize: Style.fontSizeS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: ModulesConfig.showInTray("mediaPlayer", ControlCenterState.panel) && !!MediaService.currentPlayer

                        Row {
                            width: parent.width
                            spacing: 10

                            Image {
                                width: 44
                                height: 44
                                source: MediaService.trackArtUrl
                                visible: MediaService.trackArtUrl !== ""
                                fillMode: Image.PreserveAspectCrop
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 44 - parent.spacing
                                anchors.verticalCenter: parent.verticalCenter

                                NText {
                                    text: MediaService.trackTitle
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: Colors.text
                                    pointSize: Style.fontSizeS
                                    font.weight: Style.fontWeightBold
                                }

                                NText {
                                    text: MediaService.trackArtist
                                    width: parent.width
                                    elide: Text.ElideRight
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 14

                            NIconButton {
                                baseSize: 26
                                icon: ""
                                enabled: MediaService.canGoPrevious
                                onClicked: MediaService.previous()
                            }

                            NIconButton {
                                baseSize: 30
                                icon: MediaService.isPlaying ? "" : ""
                                onClicked: MediaService.playPause()
                            }

                            NIconButton {
                                baseSize: 26
                                icon: ""
                                enabled: MediaService.canGoNext
                                onClicked: MediaService.next()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        visible: ModulesConfig.showInTray("battery", ControlCenterState.panel) && BatteryService.batteryPresent

                        NText { text: "Battery"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        BatteryIndicator {
                            textColor: Colors.textMuted
                        }
                    }
                }

                // ==================== System ====================
                Column {
                    width: tabView.width
                    spacing: 10

                    Row {
                        spacing: 10
                        visible: ModulesConfig.showInTray("kernel", ControlCenterState.panel)

                        NText { text: "Kernel"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        KernelVersion {
                            textColor: Colors.blue
                        }
                    }

                    Row {
                        spacing: 10
                        visible: ModulesConfig.showInTray("cpu", ControlCenterState.panel)

                        NText { text: "CPU"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        CpuLoad {
                            textColor: Colors.coral
                        }
                    }

                    Row {
                        spacing: 10
                        visible: ModulesConfig.showInTray("cpuTemp", ControlCenterState.panel)

                        NText { text: "CPU Temp"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        HwmonSensor {
                            sensorLabel: "Tctl"
                            iconGlyph: ""
                            textColor: Colors.blue
                        }
                    }

                    Row {
                        spacing: 10
                        visible: ModulesConfig.showInTray("gpuTemp", ControlCenterState.panel)

                        NText { text: "GPU Temp"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        HwmonSensor {
                            sensorLabel: "edge"
                            iconGlyph: ""
                            textColor: Colors.teal
                        }
                    }

                    Row {
                        spacing: 10
                        visible: ModulesConfig.showInTray("network", ControlCenterState.panel)

                        NText { text: "Network"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                        NetworkStatus {
                            textColor: Colors.blue
                        }
                    }
                }
            }
        }
    }
}
