import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets

// Bluetooth flyout: adapter power toggle, scan-for-devices toggle, and a
// list of every device BlueZ knows about (paired or freshly discovered)
// with pair/connect/disconnect/forget actions. Talks to BlueZ directly over
// D-Bus via Quickshell's own Quickshell.Bluetooth module - no shelling out
// to `bluetoothctl` anywhere. Pairing confirmation (PIN/passkey/"just
// works") is handled internally by Quickshell's own bundled agent; there's
// no separate agent API exposed to QML to hook into, so a device that
// specifically needs an on-screen PIN entry (legacy keyboards, mostly)
// isn't handled here - "just works" SSP (the overwhelming majority of
// modern audio/input devices) is.
// windowrule=float + center,title:^Bluetooth$ in zaris.conf places it like
// the settings/overflow windows - same mechanism, nothing new WM-side.
FloatingWindow {
    id: panel

    visible: BluetoothPanelState.visible
    title: "Bluetooth"

    implicitWidth: 360
    implicitHeight: Math.min(content.implicitHeight + 40, 480)

    readonly property var adapter: Bluetooth.defaultAdapter

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: content.implicitHeight
            clip: true

            Column {
                id: content
                width: parent.width
                spacing: 14

                Text {
                    text: "Bluetooth"
                    font.pixelSize: 16
                    font.bold: true
                    color: Colors.text
                }

                // --- no adapter at all: bluetoothd likely isn't running ---
                Text {
                    visible: !panel.adapter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "No Bluetooth adapter found. Is bluetoothd running?"
                    color: Colors.textMuted
                    font.pixelSize: 12
                }

                // --- adapter power + scan toggles ---
                Row {
                    visible: !!panel.adapter
                    width: parent.width
                    height: 32
                    spacing: 12

                    Text {
                        text: "Power"
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        font.pixelSize: 13
                    }

                    Rectangle {
                        width: 44
                        height: 22
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: panel.adapter && panel.adapter.enabled ? Colors.pillActive : Colors.pill
                        border.color: Colors.textMuted
                        border.width: 1

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            y: 2
                            x: (panel.adapter && panel.adapter.enabled) ? parent.width - width - 2 : 2
                            color: Colors.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.adapter.enabled = !panel.adapter.enabled
                        }
                    }
                }

                Row {
                    visible: !!panel.adapter && panel.adapter.enabled
                    width: parent.width
                    height: 32
                    spacing: 12

                    Text {
                        text: "Scan"
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        font.pixelSize: 13
                    }

                    Rectangle {
                        width: scanLabel.implicitWidth + 24
                        height: 26
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: panel.adapter && panel.adapter.discovering ? Colors.pillActive : Colors.pill

                        Text {
                            id: scanLabel
                            anchors.centerIn: parent
                            text: panel.adapter && panel.adapter.discovering ? "Scanning..." : "Scan for devices"
                            color: Colors.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.adapter.discovering = !panel.adapter.discovering
                        }
                    }
                }

                Text {
                    visible: !!panel.adapter && panel.adapter.enabled
                    text: "Devices"
                    font.pixelSize: 14
                    font.bold: true
                    color: Colors.text
                    topPadding: 6
                }

                Repeater {
                    model: panel.adapter && panel.adapter.enabled ? panel.adapter.devices : null

                    Rectangle {
                        id: deviceRow
                        required property var modelData

                        width: content.width
                        height: deviceLayout.implicitHeight + 16
                        radius: 8
                        color: Colors.pill

                        Column {
                            id: deviceLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 10
                            spacing: 4

                            Row {
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: parent.width - statusText.implicitWidth - 8
                                    text: deviceRow.modelData.name || deviceRow.modelData.deviceName || deviceRow.modelData.address
                                    color: Colors.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: statusText
                                    text: {
                                        const d = deviceRow.modelData
                                        if (d.pairing)
                                            return "pairing..."
                                        if (d.connected)
                                            return "connected"
                                        if (d.paired)
                                            return "paired"
                                        return "available"
                                    }
                                    color: deviceRow.modelData.connected ? Colors.teal : Colors.textMuted
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                visible: deviceRow.modelData.batteryAvailable
                                text: "Battery: " + Math.round(deviceRow.modelData.battery * 100) + "%"
                                color: Colors.textMuted
                                font.pixelSize: 11
                            }

                            Row {
                                spacing: 8

                                Rectangle {
                                    visible: !deviceRow.modelData.paired && !deviceRow.modelData.pairing
                                    width: pairLabel.implicitWidth + 20
                                    height: 24
                                    radius: 6
                                    color: Colors.pillActive

                                    Text {
                                        id: pairLabel
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: Colors.text
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: deviceRow.modelData.pair()
                                    }
                                }

                                Rectangle {
                                    visible: deviceRow.modelData.pairing
                                    width: cancelPairLabel.implicitWidth + 20
                                    height: 24
                                    radius: 6
                                    color: Colors.pill

                                    Text {
                                        id: cancelPairLabel
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: Colors.textMuted
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: deviceRow.modelData.cancelPair()
                                    }
                                }

                                Rectangle {
                                    visible: deviceRow.modelData.paired && !deviceRow.modelData.connected && !deviceRow.modelData.pairing
                                    width: connectLabel.implicitWidth + 20
                                    height: 24
                                    radius: 6
                                    color: Colors.pillActive

                                    Text {
                                        id: connectLabel
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: Colors.text
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: deviceRow.modelData.connect()
                                    }
                                }

                                Rectangle {
                                    visible: deviceRow.modelData.connected
                                    width: disconnectLabel.implicitWidth + 20
                                    height: 24
                                    radius: 6
                                    color: Colors.pill

                                    Text {
                                        id: disconnectLabel
                                        anchors.centerIn: parent
                                        text: "Disconnect"
                                        color: Colors.text
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: deviceRow.modelData.disconnect()
                                    }
                                }

                                Rectangle {
                                    visible: deviceRow.modelData.paired
                                    width: forgetLabel.implicitWidth + 20
                                    height: 24
                                    radius: 6
                                    color: Colors.pill

                                    Text {
                                        id: forgetLabel
                                        anchors.centerIn: parent
                                        text: "Forget"
                                        color: Colors.coral
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: deviceRow.modelData.forget()
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !!panel.adapter && panel.adapter.enabled && panel.adapter.devices.count === 0
                    text: "No devices found yet - try scanning."
                    color: Colors.textMuted
                    font.pixelSize: 12
                }
            }
        }
    }
}
