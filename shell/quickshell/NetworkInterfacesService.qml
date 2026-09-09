pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live wired + wifi device list for Settings' Network tab - deliberately
// separate from NetworkToggle.qml/WifiToggle.qml (Control Center's own
// single-device/radio-level on/off tiles, which stay untouched): this is
// a read-heavy "every interface, with live throughput" view, not another
// toggle.
//
// Two chained Processes per poll tick rather than one: `nmcli device
// status` first (to learn which ethernet/wifi devices currently exist -
// this can change at runtime, e.g. a USB wifi dongle), then a second
// Process that reads each of those devices' /sys/class/net/<dev>/
// statistics/{rx,tx}_bytes counters in one shell loop. Device names are
// passed as trailing argv elements (`"$@"` inside the script, not string-
// interpolated into the script text) specifically so a device name can
// never be interpreted as shell syntax, even though in practice interface
// names are always plain alnum (eth0, wlan0, enp2s0, ...).
//
// Throughput is a simple delta-over-wall-clock-time computation against
// the previous poll's raw counters (_lastBytes, keyed by device name) -
// the same idea `CpuLoad.qml` uses for CPU percent from `/proc/stat`'s
// cumulative counters, just wall-clock-timed here since these files have
// no exposed sampling interval "cycle count" for a two 2000ms-apart reads
// to compute the same way.
Singleton {
    id: root

    property var devices: []

    property var _lastBytes: ({})

    readonly property var ethernetDevices: root.devices.filter(function (d) { return d.type === "ethernet" })
    readonly property var wifiDevices: root.devices.filter(function (d) { return d.type === "wifi" })

    function toggle(device, connected) {
        Quickshell.execDetached(["nmcli", "device", connected ? "disconnect" : "connect", device])
    }

    Process {
        id: statusReader
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                const list = []
                for (const line of lines) {
                    if (!line)
                        continue
                    const parts = line.split(":")
                    if (parts.length < 3)
                        continue
                    const type = parts[1]
                    if (type !== "ethernet" && type !== "wifi")
                        continue
                    list.push({
                        device: parts[0],
                        type: type,
                        state: parts[2],
                        connection: parts[3] || "",
                        rxKBs: 0,
                        txKBs: 0
                    })
                }
                root._pending = list
                if (list.length === 0) {
                    root.devices = []
                    return
                }
                statsReader.command = ["sh", "-c",
                    'for d in "$@"; do printf "%s %s %s\\n" "$d" "$(cat /sys/class/net/$d/statistics/rx_bytes 2>/dev/null || echo 0)" "$(cat /sys/class/net/$d/statistics/tx_bytes 2>/dev/null || echo 0)"; done',
                    "sh"
                ].concat(list.map(function (d) { return d.device }))
                statsReader.running = true
            }
        }
    }

    property var _pending: []

    Process {
        id: statsReader
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now()
                const lines = this.text.trim().split("\n")
                const rawByDevice = {}
                for (const line of lines) {
                    const parts = line.trim().split(/\s+/)
                    if (parts.length < 3)
                        continue
                    rawByDevice[parts[0]] = { rx: parseInt(parts[1], 10) || 0, tx: parseInt(parts[2], 10) || 0 }
                }

                const list = root._pending.map(function (d) {
                    const raw = rawByDevice[d.device]
                    if (!raw)
                        return d
                    const prev = root._lastBytes[d.device]
                    if (prev) {
                        const dt = (now - prev.t) / 1000
                        if (dt > 0) {
                            d.rxKBs = Math.max(0, (raw.rx - prev.rx) / 1024 / dt)
                            d.txKBs = Math.max(0, (raw.tx - prev.tx) / 1024 / dt)
                        }
                    }
                    return d
                })

                const nextLast = {}
                for (const dev in rawByDevice)
                    nextLast[dev] = { rx: rawByDevice[dev].rx, tx: rawByDevice[dev].tx, t: now }
                root._lastBytes = nextLast
                root.devices = list
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusReader.running = true
    }
}
