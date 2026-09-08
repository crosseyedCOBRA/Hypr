import QtQuick
import QtQuick.Effects
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
// Deliberately skipped one piece of Noctalia's version that has no Zaris
// equivalent yet: weather+power-profile (no weather service or
// power-profile switching exists here - weather specifically is next up,
// per the user, not folded into this pass).
//
// Eighth pass: added the profile header (avatar, display name, uptime)
// this file's own comment used to list as intentionally skipped - "the
// bar's own clock is already visible behind this panel" reasoning applied
// to the clock specifically, not the profile block as a whole, and the
// user asked for the full header once the rest of the panel was in place.
// `HostService.qml` already had `displayName`/`username` from Phase 1
// (ported but never given a real use site until now) - only `uptimeText`
// is new there. No real `~/.face` exists on this machine, so the avatar
// falls back to a single-letter badge (`DockIcons.qml`'s existing
// fallback-avatar pattern, reused verbatim: `Colors.pill` circle + bold
// first-letter `NText`) - real-photo support (a `MultiEffect` circular
// mask, since Qt Quick's `Image` can't clip to a non-rectangular shape on
// its own) was verified separately with a throwaway test file, not left
// unverified just because this machine has nothing to show through it.
//
// Seventh pass: the media card is now a real "now playing" card (album art
// as a full-bleed background behind title/artist/album, a real seek
// scrubber via MediaService.seekByRatio(), bigger playback buttons) rather
// than a small thumbnail+text row, matching Noctalia's reference Control
// Center screenshot (not just its bar, which is all earlier passes had to
// go on). The old single master-volume row is now a real audio section -
// separate Output and Input columns, each with its own mute button,
// elided device `description` (Quickshell's Pipewire `PwNode`, confirmed
// via its qmltypes - `name`/`description`/`nickname` all exist, `description`
// reads closest to Noctalia's own verbose device names), and volume
// slider - `Pipewire.defaultAudioSource` (the input/mic device) is newly
// tracked alongside the existing `defaultAudioSink`.
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
    // Widened a bit and given real side padding (the content column stays
    // at its existing contentWidth, just with more breathing room on
    // either side of it now) plus a subtle outer border - a cleaner match
    // for Noctalia's own reference screenshot, which has visible padding
    // and a bit of background definition around its Control Center rather
    // than content running edge-to-edge.
    implicitWidth: 440
    implicitHeight: 830

    readonly property PwNode pwSink: Pipewire.defaultAudioSink
    readonly property PwNode pwSource: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: (root.pwSink ? [root.pwSink] : []).concat(root.pwSource ? [root.pwSource] : [])
    }

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
        border.width: 1
        border.color: Colors.pill

        Column {
            id: content
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 12
            spacing: 12

            Item {
                width: root.contentWidth
                height: 44

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Item {
                        id: avatar
                        width: 44
                        height: 44
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: faceImage
                            // The `?v=` query string does nothing to which
                            // file actually loads (file:// URLs ignore
                            // query strings) - it's purely there so
                            // AvatarPickerPanel.qml bumping
                            // AvatarPickerPanelState.version after
                            // overwriting ~/.face in place forces QML's
                            // image cache (keyed on the full URL string,
                            // not the file's actual contents) to treat it
                            // as a different image and reload, rather than
                            // keep showing whatever it cached before.
                            source: "file://" + Quickshell.env("HOME") + "/.face?v=" + AvatarPickerPanelState.version
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            width: avatar.width
                            height: avatar.height
                            visible: false
                            layer.enabled: true
                        }

                        Rectangle {
                            id: avatarMask
                            width: avatar.width
                            height: avatar.height
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: faceImage
                            maskEnabled: true
                            maskSource: avatarMask
                            visible: faceImage.status === Image.Ready
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/zaris-logo-circle.png"
                            visible: faceImage.status !== Image.Ready
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: avatarArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AvatarPickerPanelState.visible = true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: avatarArea.containsMouse ? 2 : 0
                            border.color: Colors.pillActive
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        NText {
                            text: HostService.displayName
                            color: Colors.text
                            pointSize: Style.fontSizeM
                            font.weight: Style.fontWeightBold
                        }

                        NText {
                            text: "Uptime: " + HostService.uptimeText
                            visible: HostService.uptimeText !== ""
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }
                }

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

            Row {
                width: root.contentWidth
                spacing: 14
                visible: ModulesConfig.showInTray("volume", ControlCenterState.panel) && ((!!root.pwSink && root.pwSink.ready) || (!!root.pwSource && root.pwSource.ready))

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4
                    visible: !!root.pwSink && root.pwSink.ready

                    Row {
                        width: parent.width
                        spacing: 6

                        NIconButton {
                            baseSize: 22
                            icon: (root.pwSink && root.pwSink.ready && root.pwSink.audio.muted) ? "󰖁" : ""
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (root.pwSink)
                                    root.pwSink.audio.muted = !root.pwSink.audio.muted
                            }
                        }

                        NText {
                            text: root.pwSink && root.pwSink.ready ? root.pwSink.description : ""
                            width: parent.width - 22 - parent.spacing
                            elide: Text.ElideRight
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    NSlider {
                        width: parent.width
                        from: 0
                        to: 1.0
                        value: root.pwSink && root.pwSink.ready ? root.pwSink.audio.volume : 0
                        onMoved: {
                            if (root.pwSink)
                                root.pwSink.audio.volume = value
                        }
                    }
                }

                Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 4
                    visible: !!root.pwSource && root.pwSource.ready

                    Row {
                        width: parent.width
                        spacing: 6

                        NIconButton {
                            baseSize: 22
                            icon: (root.pwSource && root.pwSource.ready && root.pwSource.audio.muted) ? "" : ""
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (root.pwSource)
                                    root.pwSource.audio.muted = !root.pwSource.audio.muted
                            }
                        }

                        NText {
                            text: root.pwSource && root.pwSource.ready ? root.pwSource.description : ""
                            width: parent.width - 22 - parent.spacing
                            elide: Text.ElideRight
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    NSlider {
                        width: parent.width
                        from: 0
                        to: 1.0
                        value: root.pwSource && root.pwSource.ready ? root.pwSource.audio.volume : 0
                        onMoved: {
                            if (root.pwSource)
                                root.pwSource.audio.volume = value
                        }
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

                // Power profile - a single button that cycles through the
                // three power-profiles-daemon profiles on each click,
                // rather than the three separate tiles this shipped with
                // originally (a user request after seeing that version
                // live - one tile fits the grid's existing visual language
                // better than a wide three-way row). See
                // PowerProfileState.qml's own header comment for why this
                // is safe to ship even though that daemon isn't installed
                // on this machine yet.
                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: powerProfileArea.containsMouse ? Colors.pillActive : Colors.pill

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: PowerProfileState.profileIcon(PowerProfileState.currentProfile)
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: PowerProfileState.profileLabel(PowerProfileState.currentProfile)
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: powerProfileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: PowerProfileState.cycleProfile()
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
                    id: mediaCard
                    width: 230
                    spacing: 8
                    // The "both places at once" exception this card used to
                    // need (Noctalia's own bar shows a compact "now playing"
                    // widget alongside this same rich card in its Control
                    // Center) no longer applies - the user asked to drop
                    // Bar.qml's MediaWidget now that this card exists,
                    // since showing the same now-playing info in both spots
                    // was redundant. `mediaPlayer`'s tray default flipped to
                    // `true` at the same time (ModulesConfig.qml), so this
                    // card is properly gated like every other tile here now.
                    visible: ModulesConfig.showInTray("mediaPlayer", ControlCenterState.panel) && !!MediaService.currentPlayer

                    Item {
                        width: parent.width
                        height: 130
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.radiusS
                            color: Colors.pill
                        }

                        Image {
                            anchors.fill: parent
                            source: MediaService.trackArtUrl
                            visible: MediaService.trackArtUrl !== ""
                            fillMode: Image.PreserveAspectCrop
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.1) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            width: parent.width - 20
                            spacing: 1

                            NText {
                                text: MediaService.trackTitle
                                width: parent.width
                                elide: Text.ElideRight
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                            }

                            NText {
                                text: MediaService.trackArtist
                                width: parent.width
                                elide: Text.ElideRight
                                color: Colors.coral
                                pointSize: Style.fontSizeS
                            }

                            NText {
                                text: MediaService.trackAlbum
                                width: parent.width
                                visible: MediaService.trackAlbum !== ""
                                elide: Text.ElideRight
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }
                        }
                    }

                    NSlider {
                        width: parent.width
                        from: 0
                        to: 1.0
                        enabled: MediaService.canSeek
                        value: MediaService.trackLength > 0 ? Math.min(1, MediaService.currentPosition / MediaService.trackLength) : 0
                        onMoved: MediaService.seekByRatio(value)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18

                        NIconButton {
                            baseSize: 28
                            icon: ""
                            enabled: MediaService.canGoPrevious
                            onClicked: MediaService.previous()
                        }

                        NIconButton {
                            baseSize: 34
                            icon: MediaService.isPlaying ? "" : ""
                            onClicked: MediaService.playPause()
                        }

                        NIconButton {
                            baseSize: 28
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

            // Weather - the one piece of the reference screenshot deferred
            // out of the seventh Control Center pass specifically so it
            // wouldn't be bundled into an already-large media/audio change.
            // No ModulesConfig tray gate - unlike the toggle/quick-launch
            // tiles above, there's no existing bar presence to preserve or
            // hide, and a location/weather API is opt-in by nature (simply
            // shows "Loading weather..." until the first fetch resolves,
            // never a silent failure).
            Row {
                width: root.contentWidth
                spacing: 12

                NText {
                    text: WeatherService.haveData ? WeatherService.iconGlyphCurrent : ""
                    color: Colors.blue
                    pointSize: Style.fontSizeXXXL
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    NText {
                        text: {
                            if (WeatherService.errorText !== "")
                                return "Weather unavailable"
                            if (!WeatherService.haveData)
                                return "Loading weather..."
                            return Math.round(WeatherService.temperatureF) + "°F  " + WeatherService.conditionTextCurrent
                        }
                        color: Colors.text
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                    }

                    NText {
                        visible: WeatherService.haveData
                        text: WeatherService.locationName + "  H:" + Math.round(WeatherService.highF) + "°  L:" + Math.round(WeatherService.lowF) + "°"
                        color: Colors.textMuted
                        pointSize: Style.fontSizeS
                    }
                }
            }
        }
    }
}
