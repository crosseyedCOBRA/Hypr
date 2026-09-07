import QtQuick
import QtQuick.Controls
import Quickshell.Io

// Wired-connection status: icon + Connected/Disconnected, link speed shown
// on hover. Auto-detects the interface holding the default route rather
// than hardcoding one.
Item {
    id: root

    property color textColor: "white"
    property bool connected: false
    property string tooltipText: ""

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        Text {
            text: ""
            color: root.textColor
            font.pixelSize: 13
        }

        Text {
            id: label
            text: root.connected ? "Connected" : "Disconnected"
            color: root.textColor
            font.pixelSize: 13
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
    }

    ToolTip.visible: hoverArea.containsMouse && root.tooltipText !== ""
    ToolTip.text: root.tooltipText

    Process {
        id: reader
        command: ["sh", "-c",
            "iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); " +
            "if [ -z \"$iface\" ]; then echo down; " +
            "else echo \"$iface $(cat /sys/class/net/$iface/operstate 2>/dev/null) $(cat /sys/class/net/$iface/speed 2>/dev/null)\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/)

                if (parts[0] === "down" || parts.length < 2) {
                    root.connected = false
                    root.tooltipText = "No active connection"
                    return
                }

                const iface = parts[0]
                const state = parts[1]
                const speed = parts[2]

                root.connected = state === "up"
                root.tooltipText = root.connected ? (iface + ": " + (speed || "?") + " Mbps") : "No active connection"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
