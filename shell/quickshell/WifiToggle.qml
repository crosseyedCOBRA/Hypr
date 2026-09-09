import QtQuick
import Quickshell
import Quickshell.Io

// Wifi radio on/off toggle for the Control Center's quick-toggle grid -
// `nmcli radio wifi on/off` (NetworkManager, confirmed actively managing
// this machine - see NetworkToggle.qml). No separate State singleton,
// same reasoning as NetworkToggle.qml. This machine's wlan0 is a real,
// present-but-currently-unused adapter (`ip -o link show` confirmed it
// exists, `nmcli radio wifi` reports the radio itself as a single global
// on/off independent of which specific wifi device is present).
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
    property bool radioEnabled: true
    // When true (the bar's own instance only - see BarStatusModules.qml),
    // a click opens Settings' Network tab (Wifi mini-tab) instead of
    // toggling the radio - Control Center's own instance leaves this
    // false, so its full-tile click keeps toggling exactly as before.
    property bool settingsShortcut: false
    property Item barSurfaceItem: null

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function toggle() {
        Quickshell.execDetached(["nmcli", "radio", "wifi", root.radioEnabled ? "off" : "on"])
        root.radioEnabled = !root.radioEnabled
    }

    NText {
        id: icon
        text: ""
        color: root.radioEnabled ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        onClicked: {
            if (root.settingsShortcut) {
                SettingsState.requestedCategory = "network"
                SettingsState.requestedNetworkSubTab = "wifi"
                SettingsState.targetItem = root.barSurfaceItem
                SettingsState.visible = true
                return
            }
            root.toggle()
        }
    }

    Process {
        id: reader
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.radioEnabled = this.text.trim() === "enabled"
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
