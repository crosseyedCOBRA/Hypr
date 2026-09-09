import QtQuick
import Quickshell.Io

// Wired-connection status: icon + interface name (matching Noctalia's bar,
// which shows e.g. "enp2s0" rather than a generic "Connected" label), link
// speed shown on hover. Auto-detects the interface holding the default
// route rather than hardcoding one.
//
// Tooltip built on the shared TooltipService (matching every other bar
// icon), not the raw QtQuick.Controls `ToolTip` attached property this
// file used originally - found and fixed a real bug while wiring up this
// icon's new click-to-open-Settings behavior: `QtQuick.Controls.ToolTip`
// creates its own real popup surface positioned directly over the trigger
// item, and on this PanelWindow-based bar (not a QtQuick.Controls
// ApplicationWindow) that popup was silently swallowing the click meant
// for the MouseArea underneath it - confirmed directly (a temporary
// onPressed debug log on the MouseArea never fired while the mouse sat
// over the icon, even though hover/the tooltip itself worked fine).
// TooltipService/Tooltip.qml don't have this problem - every other
// clickable bar icon already uses that pattern for exactly this reason.
Item {
    id: root

    property color textColor: "white"
    property bool connected: false
    property string interfaceName: ""
    property string tooltipText: ""
    // Bar's own full-width background item, so a click can open Settings
    // anchored under the bar (SettingsState.targetItem) - see
    // BarStatusModules.qml/Bar.qml for how this gets threaded down.
    property Item barSurfaceItem: null

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        NText {
            text: ""
            color: root.textColor
            pointSize: Style.fontSizeL
        }

        NText {
            id: label
            text: root.connected ? root.interfaceName : "Disconnected"
            color: root.textColor
            pointSize: Style.fontSizeL
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if (root.tooltipText !== "")
                TooltipService.show(root, root.tooltipText)
        }
        onExited: TooltipService.hide()
        onClicked: {
            TooltipService.hide()
            SettingsState.requestedCategory = "network"
            SettingsState.requestedNetworkSubTab = "ethernet"
            SettingsState.targetItem = root.barSurfaceItem
            SettingsState.visible = true
        }
    }

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
                root.interfaceName = iface
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
