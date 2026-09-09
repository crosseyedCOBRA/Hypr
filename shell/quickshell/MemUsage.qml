import QtQuick
import Quickshell.Io

// RAM usage percent - new for Control Center's vertical gauge stack (see
// ROADMAP.md). Mirrors CpuLoad.qml's own /proc-based polling style:
// MemAvailable (not MemFree - MemFree alone doesn't count reclaimable
// cache/buffers as "available", which would read as a permanently
// near-full bar even at idle, the same distinction `free -h`'s own
// "available" column exists to fix) against MemTotal from /proc/meminfo.
Item {
    id: root

    property real percent: 0

    Process {
        id: reader
        command: ["sh", "-c", "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let total = 0
                let available = 0
                for (const line of lines) {
                    const m = line.match(/^(\w+):\s+(\d+)/)
                    if (!m)
                        continue
                    if (m[1] === "MemTotal")
                        total = Number(m[2])
                    else if (m[1] === "MemAvailable")
                        available = Number(m[2])
                }
                if (total > 0)
                    root.percent = ((total - available) / total) * 100
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
