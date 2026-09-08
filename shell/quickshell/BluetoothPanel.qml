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
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): the plain
// Flickable is now NScrollView, every raw Text is now NText, and every
// hand-rolled "button" Rectangle+Text+MouseArea (Scan, Pair, Cancel,
// Connect, Disconnect, Forget) is now NButton, sized down via a smaller
// fontSize to keep the same compact device-row density the originals had
// rather than NButton's own larger default padding.
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

        NScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 20

            Column {
                id: content
                width: scrollView.availableWidth
                spacing: 14

                NText {
                    text: "Bluetooth"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                    color: Colors.text
                }

                // --- no adapter at all: bluetoothd likely isn't running ---
                NText {
                    visible: !panel.adapter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "No Bluetooth adapter found. Is bluetoothd running?"
                    color: Colors.textMuted
                    pointSize: Style.fontSizeS
                }

                // --- adapter power + scan toggles ---
                Row {
                    visible: !!panel.adapter
                    width: parent.width
                    height: 32
                    spacing: 12

                    NText {
                        text: "Power"
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        pointSize: Style.fontSizeM
                    }

                    ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !!(panel.adapter && panel.adapter.enabled)
                        onToggled: newChecked => panel.adapter.enabled = newChecked
                    }
                }

                Row {
                    visible: !!panel.adapter && panel.adapter.enabled
                    width: parent.width
                    height: 32
                    spacing: 12

                    NText {
                        text: "Scan"
                        width: 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.text
                        pointSize: Style.fontSizeM
                    }

                    NButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.adapter && panel.adapter.discovering ? "Scanning..." : "Scan for devices"
                        fontSize: Style.fontSizeS
                        backgroundColor: panel.adapter && panel.adapter.discovering ? Colors.pillActive : Colors.pill
                        textColor: Colors.text
                        onClicked: panel.adapter.discovering = !panel.adapter.discovering
                    }
                }

                NText {
                    visible: !!panel.adapter && panel.adapter.enabled
                    text: "Devices"
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold
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

                                NText {
                                    width: parent.width - statusText.implicitWidth - 8
                                    text: deviceRow.modelData.name || deviceRow.modelData.deviceName || deviceRow.modelData.address
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                    elide: Text.ElideRight
                                }

                                NText {
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
                                    pointSize: Style.fontSizeXS
                                }
                            }

                            NText {
                                visible: deviceRow.modelData.batteryAvailable
                                text: "Battery: " + Math.round(deviceRow.modelData.battery * 100) + "%"
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Row {
                                spacing: 8

                                NButton {
                                    visible: !deviceRow.modelData.paired && !deviceRow.modelData.pairing
                                    text: "Pair"
                                    fontSize: Style.fontSizeXS
                                    backgroundColor: Colors.pillActive
                                    textColor: Colors.text
                                    onClicked: deviceRow.modelData.pair()
                                }

                                NButton {
                                    visible: deviceRow.modelData.pairing
                                    text: "Cancel"
                                    fontSize: Style.fontSizeXS
                                    backgroundColor: Colors.pill
                                    textColor: Colors.textMuted
                                    onClicked: deviceRow.modelData.cancelPair()
                                }

                                NButton {
                                    visible: deviceRow.modelData.paired && !deviceRow.modelData.connected && !deviceRow.modelData.pairing
                                    text: "Connect"
                                    fontSize: Style.fontSizeXS
                                    backgroundColor: Colors.pillActive
                                    textColor: Colors.text
                                    onClicked: deviceRow.modelData.connect()
                                }

                                NButton {
                                    visible: deviceRow.modelData.connected
                                    text: "Disconnect"
                                    fontSize: Style.fontSizeXS
                                    backgroundColor: Colors.pill
                                    textColor: Colors.text
                                    onClicked: deviceRow.modelData.disconnect()
                                }

                                NButton {
                                    visible: deviceRow.modelData.paired
                                    text: "Forget"
                                    fontSize: Style.fontSizeXS
                                    backgroundColor: Colors.pill
                                    textColor: Colors.coral
                                    onClicked: deviceRow.modelData.forget()
                                }
                            }
                        }
                    }
                }

                NText {
                    visible: !!panel.adapter && panel.adapter.enabled && panel.adapter.devices.count === 0
                    text: "No devices found yet - try scanning."
                    color: Colors.textMuted
                    pointSize: Style.fontSizeS
                }
            }
        }
    }
}
