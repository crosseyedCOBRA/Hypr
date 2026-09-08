import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Phase 3 of the Noctalia-port effort (see ROADMAP.md): the "hidden tray"
// flyout, rebuilt as a single-column Control Center - header actions,
// quick-toggle grid, quick-launch actions, volume, kernel/network status,
// then a media card paired with a small cluster of circular system-stat
// gauges (CPU load, CPU/GPU temp, battery). Not a port of Noctalia v5's own
// Control Center (its code is Wayland/OpenGL-native, nothing to port),
// just the same idea built from Zaris's existing services: a richer, more
// scannable landing spot than one long column of label+widget rows.
// Deliberately skipped two pieces of Noctalia's version that have no Zaris
// equivalent yet: an avatar/large clock (the bar's own clock is already
// visible behind this panel, wherever it's opened from) and weather+
// forecast/power-profile (no weather service or power-profile switching
// exists here - real future features, not folded into this pass).
//
// Third pass: dropped the Home/System tab split from the second pass -
// the user asked for the "System" section folded back into the main view
// after seeing Noctalia's own reference screenshot has no tabs at all,
// just one continuous column. Kernel/Network moved up into the main flow
// as plain rows; CPU load, CPU temp, GPU temp, and Battery became
// NCircularGauge dials (matching the small circular readouts clustered
// next to Noctalia's own media card) instead of separate label+row lines.
//
// Second pass: Settings, the power menu, and a close button moved here
// from being bare always-visible Bar.qml icons (a fixed header, visible
// at the top of the column); Clipboard, Wallpaper, and Screenshot got a
// quick-launch icon row (opening the same existing panels/script their old
// bar icons did). Clipboard/Wallpaper/Battery/Dnd's `modules.json` `tray`
// default flipped to `true` at the same time (ModulesConfig.qml), so they
// stop appearing inline in the bar automatically - no Bar.qml changes
// needed for those four, the existing tray mechanism already covers it.
//
// Same "tray": true opt-in from modules.json still gates every module here,
// exactly as it did in the old flat Overflow.qml - this is a presentation
// change, not a new config surface. Live state (StayAwake, NightLight, Dnd,
// Bluetooth, volume, media) is read from the same shared singletons/
// services the bar's inline modules use, so toggling from here stays in
// sync with the bar.
FloatingWindow {
    id: root

    visible: ControlCenterState.visible
    title: "Control Center"

    // Fixed size, same reasoning as Settings.qml's fixed 680x460 - a real
    // bug found while building the second pass (not just a Xephyr-sandbox
    // artifact, confirmed via a debug Timer on the LIVE desktop with a
    // real WM running): FloatingWindow's actual OS-level height never
    // tracked content.implicitHeight growing after first map. Sidestepped
    // the same way Settings.qml already does for its own differently-sized
    // categories - one fixed size generous enough for the tallest state
    // this panel can be in (every optional row/dial visible at once).
    implicitWidth: 404
    implicitHeight: 560

    readonly property PwNode pwSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.pwSink ? [root.pwSink] : [] }

    readonly property int labelWidth: 80
    readonly property int contentWidth: 380
    readonly property int tileWidth: 150
    readonly property int tileHeight: 64

    // Hidden property sources for the CPU/temp gauges below - reuse
    // CpuLoad.qml/HwmonSensor.qml's own already-proven live-polling logic
    // (Process/Timer) rather than re-deriving /proc/stat or hwmon parsing,
    // just without their own built-in icon+text Row (NCircularGauge draws
    // its own). Timers keep running regardless of visible: false - only
    // their own internal Row rendering is suppressed.
    CpuLoad {
        id: cpuSource
        visible: false
    }

    HwmonSensor {
        id: cpuTempSource
        sensorLabel: "Tctl"
        iconGlyph: ""
        visible: false
    }

    HwmonSensor {
        id: gpuTempSource
        sensorLabel: "edge"
        iconGlyph: ""
        visible: false
    }

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
                width: root.contentWidth
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

            Grid {
                width: root.contentWidth
                columns: 2
                spacing: 10

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: stayAwakeToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("stayAwake", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        StayAwake {
                            id: stayAwakeToggle
                            clickable: false
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

                    MouseArea {
                        id: stayAwakeToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: stayAwakeToggle.toggle()
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: nightLightToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("nightLight", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NightLight {
                            id: nightLightToggle
                            clickable: false
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

                    MouseArea {
                        id: nightLightToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: nightLightToggle.toggle()
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: dndToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("dnd", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Dnd {
                            id: dndToggle
                            clickable: false
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

                    MouseArea {
                        id: dndToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dndToggle.toggle()
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: bluetoothToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("bluetooth", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        BluetoothIndicator {
                            id: bluetoothToggle
                            clickable: false
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

                    MouseArea {
                        id: bluetoothToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: bluetoothToggle.toggle()
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: networkToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("network", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NetworkToggle {
                            id: networkToggle
                            clickable: false
                            anchors.horizontalCenter: parent.horizontalCenter
                            textColor: Colors.textMuted
                            activeColor: Colors.blue
                        }

                        NText {
                            text: "Network"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: networkToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: networkToggle.toggle()
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: wifiToggleArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("wifi", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        WifiToggle {
                            id: wifiToggle
                            clickable: false
                            anchors.horizontalCenter: parent.horizontalCenter
                            textColor: Colors.textMuted
                            activeColor: Colors.blue
                        }

                        NText {
                            text: "Wifi"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: wifiToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wifiToggle.toggle()
                    }
                }
            }

            Grid {
                width: root.contentWidth
                columns: 2
                spacing: 10

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: clipboardTileArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("clipboard", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: ""
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: "Clipboard"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: clipboardTileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ClipboardHistoryPanelState.visible = !ClipboardHistoryPanelState.visible
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: wallpaperTileArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: ModulesConfig.showInTray("wallpaper", ControlCenterState.panel)

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: ""
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: "Wallpaper"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: wallpaperTileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: WallpaperPickerPanelState.visible = !WallpaperPickerPanelState.visible
                    }
                }

                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: screenshotTileArea.containsMouse ? Colors.pillActive : Colors.pill

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: ""
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: "Screenshot"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: screenshotTileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            const script = Quickshell.env("HOME") + "/.config/zaris/screenshot.sh"
                            if (mouse.button === Qt.LeftButton)
                                Quickshell.execDetached([script])
                            else
                                Quickshell.execDetached([script, "full"])
                        }
                    }
                }
            }

            Row {
                width: root.contentWidth
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

            Row {
                width: root.contentWidth
                spacing: 10
                visible: ModulesConfig.showInTray("kernel", ControlCenterState.panel)

                NText { text: "Kernel"; width: root.labelWidth; color: Colors.textMuted; pointSize: Style.fontSizeS }

                KernelVersion {
                    textColor: Colors.blue
                }
            }

            Row {
                width: root.contentWidth
                spacing: 14

                Column {
                    width: 230
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

                Grid {
                    columns: 2
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    NCircularGauge {
                        visible: ModulesConfig.showInTray("cpu", ControlCenterState.panel)
                        value: cpuSource.percent / 100
                        valueText: Math.round(cpuSource.percent) + "%"
                        icon: ""
                        fillColor: Colors.coral
                    }

                    NCircularGauge {
                        visible: ModulesConfig.showInTray("cpuTemp", ControlCenterState.panel)
                        value: cpuTempSource.tempC / 100
                        valueText: cpuTempSource.haveReading ? Math.round(cpuTempSource.tempC) + "°" : "--"
                        icon: ""
                        fillColor: Colors.blue
                    }

                    NCircularGauge {
                        visible: ModulesConfig.showInTray("gpuTemp", ControlCenterState.panel)
                        value: gpuTempSource.tempC / 100
                        valueText: gpuTempSource.haveReading ? Math.round(gpuTempSource.tempC) + "°" : "--"
                        icon: ""
                        fillColor: Colors.teal
                    }

                    NCircularGauge {
                        visible: ModulesConfig.showInTray("battery", ControlCenterState.panel) && BatteryService.batteryPresent
                        value: BatteryService.batteryPercentage / 100
                        valueText: BatteryService.batteryPercentage + "%"
                        icon: BatteryService.batteryIcon
                        fillColor: BatteryService.isCriticalBattery(BatteryService.primaryDevice) ? Colors.red : (BatteryService.isLowBattery(BatteryService.primaryDevice) ? Colors.coral : Colors.teal)
                    }
                }
            }
        }
    }
}
