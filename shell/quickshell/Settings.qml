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
        volume: "Volume",
        stayAwake: "Stay awake",
        nightLight: "Night light",
        bluetooth: "Bluetooth"
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

                                Text {
                                    text: navItem.modelData.icon
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: navItem.modelData.label
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    font.pixelSize: 13
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

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 20
                    contentHeight: contentColumn.implicitHeight
                    clip: true

                    Column {
                        id: contentColumn
                        width: parent.width
                        spacing: 4

                        Text {
                            text: settingsWindow.categoryLabel(settingsWindow.activeCategory)
                            font.pixelSize: 18
                            font.bold: true
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

                                Text { text: "Module"; width: 170; color: Colors.textMuted; font.pixelSize: 12; font.bold: true }
                                Text { text: "Enabled"; width: 80; color: Colors.textMuted; font.pixelSize: 12; font.bold: true }
                                Text { text: "Screens"; width: 140; color: Colors.textMuted; font.pixelSize: 12; font.bold: true }
                                Text { text: "In tray"; width: 80; color: Colors.textMuted; font.pixelSize: 12; font.bold: true }
                            }

                            Repeater {
                                model: ModulesConfig.moduleIds

                                Row {
                                    id: row
                                    required property string modelData
                                    width: contentColumn.width
                                    height: 40

                                    readonly property var entry: ModulesConfig.configFile.adapter[modelData]

                                    Text {
                                        text: settingsWindow.moduleNames[row.modelData] || row.modelData
                                        width: 170
                                        color: Colors.text
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        width: 44
                                        height: 22
                                        radius: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: row.entry.enabled !== false ? Colors.pillActive : Colors.pill
                                        border.color: Colors.textMuted
                                        border.width: 1

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
                                            y: 2
                                            x: (row.entry.enabled !== false) ? parent.width - width - 2 : 2
                                            color: Colors.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: ModulesConfig.setEnabled(row.modelData, row.entry.enabled === false)
                                        }
                                    }

                                    Item { width: 36; height: 1 }

                                    Row {
                                        width: 140
                                        spacing: 6
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 44
                                            height: 22
                                            radius: 6
                                            color: row.entry.screens === "all" || row.entry.screens === undefined ? Colors.pillActive : Colors.pill

                                            Text {
                                                anchors.centerIn: parent
                                                text: "All"
                                                font.pixelSize: 11
                                                color: Colors.text
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: ModulesConfig.setScreens(row.modelData, "all")
                                            }
                                        }

                                        Rectangle {
                                            width: 60
                                            height: 22
                                            radius: 6
                                            color: row.entry.screens === "primary" ? Colors.pillActive : Colors.pill

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Primary"
                                                font.pixelSize: 11
                                                color: Colors.text
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: ModulesConfig.setScreens(row.modelData, "primary")
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 44
                                        height: 22
                                        radius: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: row.entry.tray === true ? Colors.pillActive : Colors.pill
                                        border.color: Colors.textMuted
                                        border.width: 1

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
                                            y: 2
                                            x: (row.entry.tray === true) ? parent.width - width - 2 : 2
                                            color: Colors.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: ModulesConfig.setTray(row.modelData, row.entry.tray !== true)
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "\"Screens\" here only covers All / Primary - to pin a module to specific monitors by name, edit modules.json directly (\"screens\": [\"DisplayPort-1\"], matching `xrandr` output names)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                font.pixelSize: 11
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

                                Text {
                                    text: "Enabled"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    font.pixelSize: 13
                                }

                                Rectangle {
                                    width: 44
                                    height: 22
                                    radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: DockConfig.enabled ? Colors.pillActive : Colors.pill
                                    border.color: Colors.textMuted
                                    border.width: 1

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        y: 2
                                        x: DockConfig.enabled ? parent.width - width - 2 : 2
                                        color: Colors.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: DockConfig.setEnabled(!DockConfig.enabled)
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                Text {
                                    text: "Mode"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    font.pixelSize: 13
                                }

                                Row {
                                    spacing: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 80
                                        height: 22
                                        radius: 6
                                        color: DockConfig.mode === "reserved" ? Colors.pillActive : Colors.pill

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Reserved"
                                            font.pixelSize: 11
                                            color: Colors.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: DockConfig.setMode("reserved")
                                        }
                                    }

                                    Rectangle {
                                        width: 80
                                        height: 22
                                        radius: 6
                                        color: DockConfig.mode === "floating" ? Colors.pillActive : Colors.pill

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Floating"
                                            font.pixelSize: 11
                                            color: Colors.text
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: DockConfig.setMode("floating")
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Reserved permanently reserves screen space at the bottom of the primary monitor, like the bar does. Floating overlays on top of windows instead without reserving space - windows can tile underneath it. Pin apps to the dock via right-click on a result in the launcher."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                font.pixelSize: 11
                                topPadding: 6
                            }
                        }
                    }
                }
            }
        }
    }
}
