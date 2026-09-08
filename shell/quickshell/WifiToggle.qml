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
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property bool radioEnabled: true

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: ""
        color: root.radioEnabled ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            Quickshell.execDetached(["nmcli", "radio", "wifi", root.radioEnabled ? "off" : "on"])
            root.radioEnabled = !root.radioEnabled
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
