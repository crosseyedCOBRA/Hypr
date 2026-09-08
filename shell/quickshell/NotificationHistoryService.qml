pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Notification history via dunst's own `dunstctl history` (confirmed live:
// outputs real JSON, and `history-rm ID`/`history-clear` both work) -
// reads dunst's existing history buffer directly rather than building a
// second notification-tracking mechanism of our own (the only real
// alternative would be Quickshell itself becoming the
// org.freedesktop.Notifications listener, which means replacing dunst
// entirely - a much bigger undertaking for something dunst already does).
//
// dunst's `timestamp` field is CLOCK_MONOTONIC microseconds, not wall-clock
// epoch time - confirmed live by comparing a just-sent notification's
// timestamp against /proc/uptime's own monotonic seconds at the same
// moment (near-identical). Each refresh reads the real epoch and
// /proc/uptime together in one shell call so every notification's real
// send time can be reconstructed: bootEpoch = epoch - monotonicSeconds,
// then notifEpoch = bootEpoch + dunstTimestampMicros / 1e6 - needed for
// the panel's Today/Yesterday/Earlier filter tabs.
Singleton {
    id: root

    property var notifications: [] // [{id, appName, summary, body, iconPath, urgency, epoch}]

    function refresh() {
        reader.running = true
    }

    function removeById(id) {
        removeProc.command = ["dunstctl", "history-rm", String(id)]
        removeProc.running = true
    }

    function clearAll() {
        clearProc.running = true
    }

    Process {
        id: removeProc
        onExited: root.refresh()
    }

    Process {
        id: clearProc
        command: ["dunstctl", "history-clear"]
        onExited: root.refresh()
    }

    Process {
        id: reader
        command: ["sh", "-c", "printf 'TIME:%s:%s\\n' \"$(date +%s)\" \"$(cut -d' ' -f1 /proc/uptime)\"; dunstctl history"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const nl = text.indexOf("\n")
                if (nl === -1)
                    return

                const timeLine = text.slice(0, nl)
                const jsonText = text.slice(nl + 1)

                const parts = timeLine.split(":")
                if (parts.length < 3 || parts[0] !== "TIME")
                    return
                const epoch = parseFloat(parts[1])
                const monotonic = parseFloat(parts[2])
                const bootEpoch = epoch - monotonic

                try {
                    const parsed = JSON.parse(jsonText)
                    const rows = (parsed.data && parsed.data[0]) || []
                    root.notifications = rows.map(function (n) {
                        return {
                            id: n.id ? n.id.data : 0,
                            appName: n.appname ? n.appname.data : "",
                            summary: n.summary ? n.summary.data : "",
                            body: n.body ? n.body.data : "",
                            iconPath: n.icon_path ? n.icon_path.data : "",
                            urgency: n.urgency ? n.urgency.data : "NORMAL",
                            epoch: bootEpoch + (n.timestamp ? n.timestamp.data / 1000000 : 0)
                        }
                    }).sort(function (a, b) { return b.epoch - a.epoch })
                } catch (e) {
                    // dunst not running yet, or no history - leave notifications as-is
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
