import QtQuick
import Quickshell.Io

// Workspace pills, backed by EWMH (_NET_DESKTOP_NAMES/_NET_CURRENT_DESKTOP)
// via wmctrl, since there's no generic X11 EWMH workspace service in
// Quickshell (unlike its native i3/Hyprland integrations). Click a pill to
// switch - wmctrl -s sends the same _NET_CURRENT_DESKTOP client message
// the WM's own EWMH handler expects.
Row {
    id: root

    spacing: 4
    property var workspaces: []

    Process {
        id: lister
        command: ["wmctrl", "-d"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.workspaces = lines.map(function (line) {
                    const m = line.match(/^(\d+)\s+([*-])\s+.*\s(\S+)$/)
                    return m ? {index: parseInt(m[1]), active: m[2] === "*", name: m[3]} : null
                }).filter(w => w !== null)
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: lister.running = true
    }

    Process { id: switcher }

    Repeater {
        model: root.workspaces

        Rectangle {
            id: pill
            required property var modelData

            width: label.implicitWidth + 16
            height: 22
            radius: Math.min(Style.radiusS, height / 2)
            color: modelData.active ? Colors.pillActive : Colors.pill

            NText {
                id: label
                anchors.centerIn: parent
                text: pill.modelData.name
                color: pill.modelData.active ? Colors.teal : Colors.textMuted
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    switcher.command = ["wmctrl", "-s", pill.modelData.index.toString()]
                    switcher.running = true
                }
            }
        }
    }
}
