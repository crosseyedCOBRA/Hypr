import QtQuick
import Quickshell
import Quickshell.Io

// Wired-network on/off toggle for the Control Center's quick-toggle grid.
// Unlike StayAwake/NightLight/Dnd, this has no separate State singleton -
// Control Center is a single global window, not per-monitor like Bar.qml,
// so there's no cross-instance sync need the singleton pattern elsewhere
// in this codebase exists to solve.
//
// Toggled via `nmcli device connect/disconnect` (NetworkManager, confirmed
// actively managing this machine's connections via `nmcli general status`
// - not just installed but unused). Finds the right device by type
// ("ethernet") rather than a hardcoded name (this machine has both eth0
// and eth1; eth1 is the real one currently in use) - prefers a *connected*
// ethernet device if one exists, else falls back to the first ethernet
// device seen, so it keeps tracking the same interface across a manual
// disconnect rather than losing track of it (a plain `ip route show
// default`-based lookup, like NetworkStatus.qml's, would lose the
// interface name the moment it's disconnected, since a disconnected
// interface holds no default route).
//
// `toggle()` is exposed (see StayAwake.qml's header comment for the full
// reasoning) so ControlCenter.qml's quick-toggle tile can drive this from
// its own full-tile MouseArea instead of just this component's small
// icon; `clickable: false` disables this component's own internal
// MouseArea for that case, avoiding a double-toggle.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property bool clickable: true
    property string interfaceName: ""
    property bool connected: false

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function toggle() {
        if (root.interfaceName === "")
            return
        Quickshell.execDetached(["nmcli", "device", root.connected ? "disconnect" : "connect", root.interfaceName])
        root.connected = !root.connected
    }

    NText {
        id: icon
        text: ""
        color: root.connected ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        onClicked: root.toggle()
    }

    Process {
        id: reader
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let chosen = null
                for (const line of lines) {
                    const parts = line.split(":")
                    if (parts.length < 3 || parts[1] !== "ethernet")
                        continue
                    if (chosen === null)
                        chosen = { dev: parts[0], state: parts[2] }
                    if (parts[2] === "connected") {
                        chosen = { dev: parts[0], state: parts[2] }
                        break
                    }
                }
                if (chosen) {
                    root.interfaceName = chosen.dev
                    root.connected = chosen.state === "connected"
                }
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
