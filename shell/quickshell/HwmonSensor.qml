import QtQuick
import Quickshell.Io

// A single hwmon temperature reading, matched by sensor label (e.g. "Tctl"
// for k10temp's CPU die sensor, "edge" for amdgpu) rather than a hardcoded
// hwmonN path, since hwmon enumeration order isn't guaranteed stable.
Row {
    id: root

    required property string sensorLabel
    required property string iconGlyph
    property color textColor: "white"

    spacing: 4

    property string inputPath: ""
    property real tempC: 0
    property bool haveReading: false

    Text {
        text: root.iconGlyph
        color: root.textColor
        font.pixelSize: 13
    }

    Text {
        text: root.haveReading ? Math.round(root.tempC) + "°C" : "--"
        color: root.textColor
        font.pixelSize: 13
    }

    // Resolve once: hwmon layout doesn't change without a reboot.
    Process {
        running: true
        command: ["sh", "-c", "grep -l '^" + root.sensorLabel + "$' /sys/class/hwmon/hwmon*/temp*_label 2>/dev/null | head -1 | sed 's/_label$/_input/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                if (p !== "")
                    root.inputPath = p
            }
        }
    }

    Process {
        id: reader
        command: ["cat", root.inputPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = parseInt(this.text)
                if (!isNaN(raw)) {
                    root.tempC = raw / 1000
                    root.haveReading = true
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: root.inputPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }
}
