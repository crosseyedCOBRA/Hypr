import QtQuick
import Quickshell

// Bar module + dock settings - a scoped-down first slice of the deferred
// GUI settings app (see ROADMAP.md), covering modules.json (enabled /
// screens / tray per bar module) and dock.json (enabled / mode) rather than
// the full WM config, which stays hand-edit-only (hypr.conf) for now. Edits
// here write straight through ModulesConfig's/DockConfig's FileViews, so
// they apply live and are visible in the underlying JSON immediately - same
// file, same effect as hand-editing it. Named "Shell Settings" (not "Bar
// Settings") since it covers both now - zaris.conf's window rules match on
// this title, so keep them in sync if this changes again.
FloatingWindow {
    id: settingsWindow

    visible: SettingsState.visible
    title: "Shell Settings"

    implicitWidth: 520
    implicitHeight: list.implicitHeight + 40

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

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            id: list
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 4

            Row {
                width: parent.width
                height: 28

                Text {
                    text: "Module"
                    width: 170
                    color: Colors.textMuted
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "Enabled"
                    width: 80
                    color: Colors.textMuted
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "Screens"
                    width: 140
                    color: Colors.textMuted
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "In tray"
                    width: 80
                    color: Colors.textMuted
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Repeater {
                model: ModulesConfig.moduleIds

                Row {
                    id: row
                    required property string modelData
                    width: list.width
                    height: 40

                    readonly property var entry: ModulesConfig.configFile.adapter[modelData]

                    Text {
                        text: settingsWindow.moduleNames[row.modelData] || row.modelData
                        width: 170
                        color: Colors.text
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // --- enabled toggle ---
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

                    // --- screens: All / Primary ---
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

                    // --- tray toggle ---
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

            Text {
                text: "Dock"
                font.pixelSize: 14
                font.bold: true
                color: Colors.text
                topPadding: 16
            }

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
