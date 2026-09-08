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
// reorganized under a nav shell instead of one flat list. Named
// "Shell Settings" (not "Bar Settings") - zaris.conf's window rules match
// on this title, keep them in sync if it changes again.
FloatingWindow {
    id: settingsWindow

    visible: SettingsState.visible
    title: "Shell Settings"

    implicitWidth: 680
    implicitHeight: 460

    property string activeCategory: "bar"

    readonly property var categories: [
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
                                text: "Reserved permanently reserves screen space at the bottom of the primary monitor, like the bar does. Floating overlays on top of windows instead without reserving space - windows can tile underneath it. Pin apps to the dock via right-click on a result in the launcher."
                                width: parent.width
                                wrapMode: Text.WordWrap
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
