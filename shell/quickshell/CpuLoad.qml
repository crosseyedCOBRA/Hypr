import QtQuick
import Quickshell.Io

// CPU load percent, computed the same way as /proc/stat-based tools:
// (user+nice+system) delta over total-jiffies delta between two samples.
Row {
    id: root

    property color textColor: "white"
    property var lastBusy: null
    property var lastTotal: null
    property real percent: 0

    spacing: 4

    Text {
        text: "" // nf-fa-microchip
        color: root.textColor
        font.pixelSize: 13
    }

    Text {
        text: Math.round(root.percent) + "%"
        color: root.textColor
        font.pixelSize: 13
    }

    Process {
        id: reader
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = this.text.trim().split(/\s+/).slice(1).map(Number)
                const busy = fields[0] + fields[1] + fields[2]
                const total = fields.reduce((a, b) => a + b, 0)

                if (root.lastTotal !== null) {
                    const totalDelta = total - root.lastTotal
                    if (totalDelta > 0)
                        root.percent = ((busy - root.lastBusy) / totalDelta) * 100
                }

                root.lastBusy = busy
                root.lastTotal = total
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
