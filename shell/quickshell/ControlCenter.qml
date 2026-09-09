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
// Built on PopupWindow rather than a FloatingWindow, same reasoning as
// Settings.qml/CalendarFlyout.qml: anchors directly to the bar's own
// full-width background surface (ControlCenterState.barItem, set by
// whichever monitor's launcher icon was actually clicked) via `anchor.item`
// rather than a WM-side `topright 14 48` windowrule fixed to one screen
// corner - the WM rule looked fine while the bar only ever lived at the
// top, but once BarConfig.position could also be "bottom" (see BarConfig's
// own comment), a fixed top-right corner would leave Control Center
// visually disconnected from a bar that's actually at the bottom of the
// screen. Right-aligned under the bar (anchor.rect.x) and opening
// above/below it depending on BarConfig.position (BarConfig.popupAnchorY,
// shared with every other bar-anchored popup) keeps it attached to the bar
// wherever the bar actually is.
PopupWindow {
    id: root

    visible: ControlCenterState.visible && !!ControlCenterState.barItem
    color: Colors.bg

    // Fixed size, same reasoning as Settings.qml's fixed 680x460 - a real
    // bug found while building the second pass (not just a Xephyr-sandbox
    // artifact, confirmed via a debug Timer on the LIVE desktop with a
    // real WM running): FloatingWindow's actual OS-level height never
    // tracked content.implicitHeight growing after first map (this window
    // was a FloatingWindow at the time; PopupWindow has never been
    // observed to have this problem, but the fixed size is kept regardless
    // since nothing about this panel's content actually needs to grow).
    // Sidestepped the same way Settings.qml already does for its own
    // differently-sized categories - one fixed size generous enough for
    // the tallest state this panel can be in (every optional row/dial
    // visible at once). Widened a bit and given real side padding (the
    // content column stays at its existing contentWidth, just with more
    // breathing room on either side of it now) plus a subtle outer border
    // - a cleaner match for Noctalia's own reference screenshot, which has
    // visible padding and a bit of background definition around its
    // Control Center rather than content running edge-to-edge.
    implicitWidth: 440
    // Fixed at 830 - tall enough for every optional row/dial visible at
    // once (see the comment above this property). A Calendar section was
    // briefly added below the gauges cluster (which needed bumping this to
    // 900 plus wrapping everything in a scrolling NScrollView so the taller
    // content wouldn't clip past a 1080px-tall monitor's usable height) but
    // the user reconsidered - Control Center should never require
    // scrolling, full stop - so the Calendar section was pulled back out
    // (it stays in CalendarFlyout.qml, under the bar's clock) rather than
    // solved with a scrollbar, and this reverts to the original fixed size.
    implicitHeight: 830

    anchor.item: ControlCenterState.barItem
    anchor.rect.x: ControlCenterState.barItem ? ControlCenterState.barItem.width - implicitWidth : 0
    anchor.rect.y: BarConfig.popupAnchorY(ControlCenterState.barItem, implicitHeight)

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

    MemUsage {
        id: memSource
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
                            // Purely a display now - clicking this avatar
                            // used to open AvatarPickerPanel.qml directly;
                            // picture changing is a Settings-only affordance
                            // now (Profile tab), per explicit request. The
                            // `?v=` query string does nothing to which file
                            // actually loads (file:// URLs ignore query
                            // strings) - it's purely there so
                            // AvatarPickerPanelState.setAvatar() bumping
                            // AvatarPickerPanelState.version after
                            // overwriting ~/.face in place (whether that
                            // came from AvatarPickerPanel.qml's own grid or
                            // Settings' typed-path field, both now go
                            // through the same shared setAvatar()) forces
                            // QML's image cache (keyed on the full URL
                            // string, not the file's actual contents) to
                            // treat it as a different image and reload,
                            // rather than keep showing whatever it cached
                            // before.
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
                        // Settings now opens as a PopupWindow anchored to
                        // the bar's own full-width surface
                        // (ControlCenterState.barItem, set by Bar.qml
                        // whenever the launcher icon is clicked) rather
                        // than a centered FloatingWindow - not this
                        // button itself, since Control Center closes at
                        // the same time Settings opens, and a
                        // PopupWindow can't anchor to a target inside a
                        // window that's just been hidden (confirmed by
                        // testing: anchoring here directly never showed
                        // anything, regardless of statement order).
                        onClicked: {
                            // Always General specifically, regardless of
                            // whichever tab Settings was last left open on -
                            // per explicit request, this gear is the one
                            // "just open Settings" entry point, distinct
                            // from the other Control Center icons that
                            // jump to their own specific tab (Ethernet,
                            // Wifi, Battery, etc.) via this same
                            // requestedCategory mechanism (see
                            // AudioMixerPanel.qml's own gear button for the
                            // first user of it).
                            SettingsState.requestedCategory = "general"
                            SettingsState.targetItem = ControlCenterState.barItem
                            SettingsState.visible = true
                            ControlCenterState.visible = false
                        }
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Power menu"
                        onClicked: {
                            PowerMenuPanelState.visible = true
                            ControlCenterState.visible = false
                        }
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Close"
                        onClicked: ControlCenterState.visible = false
                    }
                }
            }

            // Running kernel version - its own small, always-visible
            // section (not gated by ModulesConfig's enable/tray system the
            // way the bar's own copy of this module is) since the kernel
            // module's bar default flipped to disabled - the user still
            // wanted it visible somewhere by default, just not taking up
            // bar space. A second, independent KernelVersion instance
            // (its own one-shot `uname -r` Process) rather than sharing
            // the bar's - the same "duplicate the self-contained module
            // rather than share the bar's own instance" approach this file
            // already uses for cpuSource/cpuTempSource/gpuTempSource above.
            // textColor is Colors.text (this panel's own neutral text
            // color), not the bar's accent-colored textColor prop, so it
            // reads as regular themed Control Center text and follows a
            // palette change like everything else here.
            Row {
                width: root.contentWidth
                spacing: 8

                NText {
                    text: "Running Kernel"
                    color: Colors.textMuted
                    pointSize: Style.fontSizeXS
                    anchors.verticalCenter: parent.verticalCenter
                }

                KernelVersion {
                    textColor: Colors.text
                    anchors.verticalCenter: parent.verticalCenter
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


            // Wrapped in a plain Item (rather than giving the Grid itself
            // `width: root.contentWidth`) so the tiles can be truly
            // centered - a Grid lays its children out at their natural
            // size starting from its own x origin, so an explicit width
            // wider than that natural size (contentWidth's 380 vs. this
            // grid's actual 2*tileWidth+spacing = 310) just left a gap on
            // the right instead of centering, which read as the whole
            // toggle grid being "smushed" to the left side of the panel.
            Item {
                width: root.contentWidth
                height: toggleGrid.implicitHeight

                Grid {
                    id: toggleGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 2
                    spacing: 10

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

                // Battery - fixed second, in the slot the Do Not Disturb
                // tile used to occupy (see ModulesConfig.trayModuleIds'
                // own comment for why DND's tile was removed and its
                // toggle moved onto the bar's notification bell instead).
                // Not part of the reorderable Repeater below - it isn't a
                // toggle (nothing to switch on/off), it navigates to
                // Settings' Battery tab on click, the same
                // SettingsState.requestedCategory mechanism
                // AudioMixerPanel.qml's own gear button and the Settings
                // gear itself already use. Battery's own gauge presence in
                // the CPU/CPU-temp/GPU-temp/Battery cluster further down
                // this file is untouched - that's a separate, still-open
                // vertical-layout redesign (see ROADMAP.md), not
                // duplicated or removed by this tile.
                Rectangle {
                    width: root.tileWidth
                    height: root.tileHeight
                    radius: Style.radiusS
                    color: batteryTileArea.containsMouse ? Colors.pillActive : Colors.pill
                    visible: BatteryService.batteryPresent

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: BatteryService.batteryIcon
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: "Battery"
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        id: batteryTileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            SettingsState.requestedCategory = "battery"
                            SettingsState.targetItem = ControlCenterState.barItem
                            SettingsState.visible = true
                            ControlCenterState.visible = false
                        }
                    }
                }

                // The other six quick-toggle tiles - previously seven
                // near-identical hand-authored Rectangle blocks (DND, Night
                // Light, Ethernet, Wifi, Clipboard, Bluetooth, plus Stay
                // Awake now folded in here too), now one Repeater driven by
                // Settings' new "Control Center" tab (ModulesConfig
                // .trayModuleIds/.orderedTrayModules - see that file's own
                // comment for exactly which modules qualify and why). Each
                // of the six *ModulesConfig* module-toggle components
                // (Dnd/NightLight/StayAwake/NetworkToggle/WifiToggle/
                // BluetoothIndicator) shares the exact same
                // clickable/textColor/activeColor/toggle() interface, so
                // the click handler can call `loader.item.toggle()`
                // polymorphically without needing to know which one it
                // actually loaded - only Clipboard (a plain icon that opens
                // ClipboardHistoryPanel, not a stateful toggle) needs its
                // own special case.
                Repeater {
                    model: ModulesConfig.orderedTrayModules(ControlCenterState.panel)

                    Rectangle {
                        id: tileDelegate
                        required property string modelData
                        width: root.tileWidth
                        height: root.tileHeight
                        radius: Style.radiusS
                        color: tileArea.containsMouse ? Colors.pillActive : Colors.pill

                        Behavior on color {
                            ColorAnimation { duration: Style.animationFast }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Loader {
                                id: iconLoader
                                anchors.horizontalCenter: parent.horizontalCenter
                                sourceComponent: {
                                    switch (tileDelegate.modelData) {
                                    case "stayAwake": return stayAwakeIconComponent
                                    case "nightLight": return nightLightIconComponent
                                    case "network": return networkIconComponent
                                    case "wifi": return wifiIconComponent
                                    case "clipboard": return clipboardIconComponent
                                    case "bluetooth": return bluetoothIconComponent
                                    default: return null
                                    }
                                }
                            }

                            NText {
                                text: {
                                    switch (tileDelegate.modelData) {
                                    case "stayAwake": return "Stay Awake"
                                    case "nightLight": return "Night Light"
                                    case "network": return "Ethernet"
                                    case "wifi": return "Wifi"
                                    case "clipboard": return "Clipboard"
                                    case "bluetooth": return "Bluetooth"
                                    default: return ""
                                    }
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }
                        }

                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (tileDelegate.modelData === "clipboard")
                                    ClipboardHistoryPanelState.visible = !ClipboardHistoryPanelState.visible
                                else if (iconLoader.item && iconLoader.item.toggle)
                                    iconLoader.item.toggle()
                            }
                        }
                    }
                }
                }
            }

            Component {
                id: stayAwakeIconComponent
                StayAwake {
                    clickable: false
                    textColor: Colors.textMuted
                    activeColor: Colors.coral
                }
            }

            Component {
                id: nightLightIconComponent
                NightLight {
                    clickable: false
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Component {
                id: networkIconComponent
                NetworkToggle {
                    clickable: false
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Component {
                id: wifiIconComponent
                WifiToggle {
                    clickable: false
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Component {
                id: clipboardIconComponent
                NIcon {
                    icon: ""
                    color: Colors.textMuted
                    pointSize: Style.fontSizeXL
                }
            }

            Component {
                id: bluetoothIconComponent
                BluetoothIndicator {
                    clickable: false
                    textColor: Colors.textMuted
                    activeColor: Colors.blue
                }
            }

            Item {
                width: root.contentWidth
                height: quickLaunchGrid.implicitHeight

                Grid {
                    id: quickLaunchGrid
                    anchors.horizontalCenter: parent.horizontalCenter
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
                            const mode = mouse.button === Qt.LeftButton ? "region" : "full"
                            Quickshell.execDetached([script, mode, DefaultsConfig.screenshotFolder])
                        }
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

                        // Known caveat, not fixable from here - same family
                        // as MediaService.qml's own trackLength caveat
                        // (unreliable "generic browser" MPRIS metadata):
                        // confirmed live via direct `busctl ... Metadata`
                        // + a filesystem check that Chromium's own MPRIS
                        // bridge can report an `mpris:artUrl` pointing at a
                        // `/tmp/.org.chromium.Chromium.<id>` temp file that
                        // never actually loads. Originally chalked up to
                        // Chromium deleting the file "almost immediately" -
                        // re-investigated 2026-09-09 per an explicit user
                        // question about whether this is really a Chromium-
                        // as-Flatpak issue specifically, and it is: `flatpak
                        // info --show-permissions org.chromium.Chromium`
                        // grants `filesystems=home;` and a short allowlist
                        // of specific paths, with no `--filesystem=/tmp` (or
                        // `host`/`host-os`) anywhere in it. Flatpak's bubble-
                        // wrap sandbox gives every app a private, isolated
                        // `/tmp` by default unless a rule like that grants
                        // the real host one - so the path Chromium's MPRIS
                        // bridge advertises is real and valid *inside its
                        // own sandbox*, but `/tmp/.org.chromium.Chromium.
                        // <id>` on the actual host filesystem (what this
                        // Image, running unsandboxed, actually reads) either
                        // doesn't exist at all or is a completely unrelated
                        // file - not a timing race that just happens to
                        // always lose, but two different filesystems that
                        // only share a path string. Still not fixable from
                        // here either way (nothing server-side changes what
                        // path Chromium's MPRIS metadata reports), but this
                        // is the accurate why - a real player run outside a
                        // sandbox (mpv, VLC, Spotify's native non-Flatpak
                        // build, etc.) isn't affected, since there's no
                        // sandbox boundary for its own real temp files to
                        // cross. This Image simply fails to load and the
                        // Colors.pill/gradient background behind it shows
                        // through instead, which is the correct graceful
                        // fallback already, not a bug to chase further.
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

                Column {
                    id: noMediaCard
                    width: 230
                    spacing: 8
                    visible: ModulesConfig.showInTray("mediaPlayer", ControlCenterState.panel) && !MediaService.currentPlayer

                    Item {
                        width: parent.width
                        height: 130

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.radiusS
                            color: Colors.pill
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            NIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: ""
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXXXL
                            }

                            NText {
                                text: "No Media Playing"
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Colors.textMuted
                                pointSize: Style.fontSizeS
                            }
                        }
                    }
                }

                Column {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    NCircularGauge {
                        diameter: 38
                        visible: ModulesConfig.configFile.adapter.ccGaugeCpu
                        value: cpuSource.percent / 100
                        valueText: Math.round(cpuSource.percent) + "%"
                        icon: ""
                        fillColor: Colors.coral
                    }

                    NCircularGauge {
                        diameter: 38
                        visible: ModulesConfig.configFile.adapter.ccGaugeCpuTemp
                        value: cpuTempSource.tempC / 100
                        valueText: cpuTempSource.haveReading ? Math.round(cpuTempSource.tempC) + "°" : "--"
                        icon: ""
                        fillColor: Colors.blue
                    }

                    NCircularGauge {
                        diameter: 38
                        visible: ModulesConfig.configFile.adapter.ccGaugeGpuTemp
                        value: gpuTempSource.tempC / 100
                        valueText: gpuTempSource.haveReading ? Math.round(gpuTempSource.tempC) + "°" : "--"
                        icon: ""
                        fillColor: Colors.teal
                    }

                    NCircularGauge {
                        diameter: 38
                        visible: ModulesConfig.configFile.adapter.ccGaugeRam
                        value: memSource.percent / 100
                        valueText: Math.round(memSource.percent) + "%"
                        icon: "󰍛"
                        fillColor: Colors.purple
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
            // never a silent failure). Now WeatherWidget.qml, shared with
            // CalendarFlyout.qml's own weather row rather than duplicated.
            WeatherWidget {
                width: root.contentWidth
            }
        }
    }
}
