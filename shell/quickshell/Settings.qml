import QtQuick
import Quickshell

// GUI settings app: sidebar (category list) + content pane, modeled after
// Noctalia's own settings panel (a screenshot of it was the direct
// reference) rather than the single long scrolling list this used to be.
// Each category maps to something that genuinely already has settings
// today (Bar's per-module config, Dock's enabled/mode) - no placeholder
// categories for features that don't exist yet. New categories get added
// as the underlying WM/shell feature they'd configure actually exists, not
// ahead of it - the full WM config (keybinds, window rules, gaps/borders)
// still has no GUI and stays hand-edit-only in zaris.conf for now (see
// ROADMAP.md's "GUI settings app, full WM config" backlog item, which this
// is the first step of).
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): this is the first
// existing screen rebuilt to actually use the ported widget library rather
// than the original hand-rolled Rectangle/Text pattern - the plain
// Flickable is now NScrollView (real scrollbar styling + smooth wheel
// scroll), raw Text is now NText throughout (consistent typography off
// Style.qml's tokens), and the two-Rectangle "pill pair" selectors
// (screens: All/Primary, dock mode: Reserved/Floating) are now
// NTabBar/NTabButton, a genuine behavioral and visual upgrade over the
// hand-rolled pair (proper hover states, tooltip support, shared
// segmented-control styling used the same way a future settings row would
// elsewhere). The sidebar nav list is intentionally left as its own
// pattern - it's a vertical category list, not a fit for NTabBar's
// horizontal segmented-control shape.
//
// Still writes straight through the same ModulesConfig/DockConfig
// FileViews as before - same JSON files, same live-apply behavior, just
// reorganized under a nav shell instead of one flat list.
//
// Built on PopupWindow rather than a FloatingWindow, same reasoning as
// CalendarFlyout.qml/Tooltip.qml: anchors directly to the bar's own
// Control Center launcher icon (ControlCenterState.launcherItem - opened
// by clicking the gear button inside Control Center, which sets
// SettingsState.targetItem to that icon right before opening this and
// closing itself) via `anchor.item`, so it opens attached to the bar
// rather than centered on screen - needing none of Zaris's WM-side
// windowrule system, and no `title` property to match a rule against
// (PopupWindow doesn't expose one at all - positioning is entirely
// anchor-based now). Deliberately anchored to the bar icon and not the
// gear button that's actually clicked - Control Center closes at the same
// moment Settings opens, and a PopupWindow can't anchor to a target
// inside a window that's just gone invisible; the bar itself never
// closes, so it stays a valid anchor regardless of Control Center's state.
PopupWindow {
    id: settingsWindow

    visible: SettingsState.visible && !!SettingsState.targetItem
    color: Colors.bg

    implicitWidth: 680
    implicitHeight: 460

    anchor.item: SettingsState.targetItem
    // Right-aligned under the launcher icon rather than left-aligned like
    // CalendarFlyout's under the clock - the icon sits near the right edge
    // of the bar, so a left-aligned anchor would run this 680px-wide
    // window off the right side of the monitor.
    anchor.rect.x: SettingsState.targetItem ? SettingsState.targetItem.width - implicitWidth : 0
    anchor.rect.y: SettingsState.targetItem ? SettingsState.targetItem.height + 10 : 0

    property string activeCategory: "bar"

    readonly property var categories: [
        { id: "profile", label: "Profile", icon: "" },
        { id: "bar", label: "Bar", icon: "" },
        { id: "dock", label: "Dock", icon: "" }
    ]

    readonly property var moduleNames: ({
        kernel: "Kernel version",
        cpu: "CPU load",
        cpuTemp: "CPU temperature",
        gpuTemp: "GPU temperature",
        network: "Network status",
        wifi: "Wifi",
        volume: "Volume",
        stayAwake: "Stay awake",
        nightLight: "Night light",
        dnd: "Do not disturb",
        bluetooth: "Bluetooth",
        mediaPlayer: "Media player",
        clipboard: "Clipboard history",
        notifications: "Notifications",
        wallpaper: "Wallpaper picker",
        battery: "Battery status"
    })

    function categoryLabel(id) {
        for (var i = 0; i < settingsWindow.categories.length; i++) {
            if (settingsWindow.categories[i].id === id)
                return settingsWindow.categories[i].label
        }
        return ""
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        // Close button, same icon/style as Control Center's own - matters
        // more here than it did as a centered FloatingWindow, since this
        // now opens anchored under Control Center's gear button rather
        // than in the middle of the screen, without an obvious "click
        // outside to dismiss" affordance.
        NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            z: 1
            baseSize: 26
            icon: ""
            tooltipText: "Close"
            onClicked: SettingsState.visible = false
        }

        Row {
            anchors.fill: parent

            // --- sidebar ---
            Rectangle {
                width: 180
                height: parent.height
                color: Colors.pill

                Column {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 2

                    Repeater {
                        model: settingsWindow.categories

                        Rectangle {
                            id: navItem
                            required property var modelData
                            width: parent.width
                            height: 36
                            radius: 6
                            color: settingsWindow.activeCategory === modelData.id ? Colors.pillActive : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                spacing: 10

                                NIcon {
                                    icon: navItem.modelData.icon
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    pointSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                NText {
                                    text: navItem.modelData.label
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    pointSize: Style.fontSizeM
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: settingsWindow.activeCategory = navItem.modelData.id
                            }
                        }
                    }
                }
            }

            // --- content pane ---
            Item {
                width: parent.width - 180
                height: parent.height

                NScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: 20

                    Column {
                        id: contentColumn
                        width: scrollView.availableWidth
                        spacing: 4

                        NText {
                            text: settingsWindow.categoryLabel(settingsWindow.activeCategory)
                            pointSize: Style.fontSizeXL
                            font.weight: Style.fontWeightBold
                            color: Colors.text
                            bottomPadding: 16
                        }

                        // ==================== Profile ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "profile"

                            NTextInput {
                                width: 260
                                label: "Display name"
                                description: "Shown in the Control Center - separate from your actual account username, which stays " + HostService.username + "."
                                placeholderText: HostService.username
                                text: HostService.identityFile.adapter.customDisplayName
                                onEditingFinished: HostService.setCustomDisplayName(text)
                                onAccepted: HostService.setCustomDisplayName(text)
                            }

                            NTextInput {
                                width: 260
                                label: "Weather location"
                                description: WeatherService.manualLocationQuery === ""
                                    ? "Auto-detected via your IP" + (WeatherService.haveData ? " as " + WeatherService.locationName : "") + ". Type a city to override, or leave blank."
                                    : "Currently set to \"" + WeatherService.manualLocationQuery + "\". Clear this field to go back to auto-detection."
                                placeholderText: "Auto (IP-based)"
                                text: WeatherService.manualLocationQuery
                                onEditingFinished: {
                                    if (text.trim() === "")
                                        WeatherService.useAutoLocation()
                                    else
                                        WeatherService.setManualLocation(text.trim())
                                }
                                onAccepted: {
                                    if (text.trim() === "")
                                        WeatherService.useAutoLocation()
                                    else
                                        WeatherService.setManualLocation(text.trim())
                                }
                            }
                        }

                        // ==================== Bar ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "bar"

                            Row {
                                width: parent.width
                                height: 28

                                NText { text: "Module"; width: 170; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "Enabled"; width: 80; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "Screens"; width: 140; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "In tray"; width: 80; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                            }

                            Repeater {
                                model: ModulesConfig.moduleIds

                                Row {
                                    id: row
                                    required property string modelData
                                    width: contentColumn.width
                                    height: 40

                                    readonly property var entry: ModulesConfig.configFile.adapter[modelData]

                                    NText {
                                        text: settingsWindow.moduleNames[row.modelData] || row.modelData
                                        width: 170
                                        color: Colors.text
                                        pointSize: Style.fontSizeM
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    ToggleSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: row.entry.enabled !== false
                                        onToggled: newChecked => ModulesConfig.setEnabled(row.modelData, newChecked)
                                    }

                                    Item { width: 36; height: 1 }

                                    NTabBar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        tabHeight: 22

                                        NTabButton {
                                            text: "All"
                                            pointSize: Style.fontSizeS
                                            checked: row.entry.screens === "all" || row.entry.screens === undefined
                                            onClicked: ModulesConfig.setScreens(row.modelData, "all")
                                        }

                                        NTabButton {
                                            text: "Primary"
                                            pointSize: Style.fontSizeS
                                            checked: row.entry.screens === "primary"
                                            onClicked: ModulesConfig.setScreens(row.modelData, "primary")
                                        }
                                    }

                                    ToggleSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: row.entry.tray === true
                                        onToggled: newChecked => ModulesConfig.setTray(row.modelData, newChecked)
                                    }
                                }
                            }

                            NText {
                                text: "\"Screens\" here only covers All / Primary - to pin a module to specific monitors by name, edit modules.json directly (\"screens\": [\"DisplayPort-1\"], matching `xrandr` output names)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 10
                            }
                        }

                        // ==================== Dock ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "dock"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Enabled"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: DockConfig.enabled
                                    onToggled: newChecked => DockConfig.setEnabled(newChecked)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Mode"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Reserved"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.mode === "reserved"
                                        onClicked: DockConfig.setMode("reserved")
                                    }

                                    NTabButton {
                                        text: "Floating"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.mode === "floating"
                                        onClicked: DockConfig.setMode("floating")
                                    }
                                }
                            }

                            NText {
                                text: "Reserved permanently reserves screen space, like the bar does. Floating overlays on top of windows instead without reserving space - windows can tile underneath it. Pin apps to the dock via right-click on a result in the launcher."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Position"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Top"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "top"
                                        onClicked: DockConfig.setPosition("top")
                                    }

                                    NTabButton {
                                        text: "Bottom"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "bottom"
                                        onClicked: DockConfig.setPosition("bottom")
                                    }

                                    NTabButton {
                                        text: "Left"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "left"
                                        onClicked: DockConfig.setPosition("left")
                                    }

                                    NTabButton {
                                        text: "Right"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "right"
                                        onClicked: DockConfig.setPosition("right")
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Launcher position"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Start"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.launcherPosition === "start"
                                        onClicked: DockConfig.setLauncherPosition("start")
                                    }

                                    NTabButton {
                                        text: "End"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.launcherPosition === "end"
                                        onClicked: DockConfig.setLauncherPosition("end")
                                    }
                                }
                            }

                            NText {
                                text: "\"Start\" is the top/left-most end of the dock's own strip regardless of position, so it stays meaningful for a vertical (left/right) dock too."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Screens"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "All"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.configFile.adapter.screens === "all"
                                        onClicked: DockConfig.setScreens("all")
                                    }

                                    NTabButton {
                                        text: "Primary"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.configFile.adapter.screens === "primary" || DockConfig.configFile.adapter.screens === undefined
                                        onClicked: DockConfig.setScreens("primary")
                                    }
                                }
                            }

                            NText {
                                text: "Pinning to specific monitors by name is JSON-only for now (dock.json's \"screens\" field, an array of exact xrandr output names)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Background opacity"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0
                                    to: 1
                                    value: DockConfig.backgroundOpacity
                                    onMoved: DockConfig.setBackgroundOpacity(value)
                                }

                                NText {
                                    text: Math.round(DockConfig.backgroundOpacity * 100) + "%"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Background color"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: DockConfig.backgroundColor
                                    border.width: 1
                                    border.color: Colors.textMuted
                                }

                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: DockConfig.backgroundColor
                                    placeholderText: "#0c0b1a"
                                    onEditingFinished: DockConfig.setBackgroundColor(text)
                                    onAccepted: DockConfig.setBackgroundColor(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled && DockConfig.mode === "floating"

                                NText {
                                    text: "Auto-hide"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: DockConfig.autoHide
                                    onToggled: newChecked => DockConfig.setAutoHide(newChecked)
                                }
                            }

                            NText {
                                text: "Only applies in Floating mode. When on, the dock stays hidden until you hover a small marker at its position, then hides again shortly after you move away."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                visible: DockConfig.enabled && DockConfig.mode === "floating"
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                            }
                        }
                    }
                }
            }
        }
    }
}
