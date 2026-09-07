import QtQuick
import Quickshell

// Manual "stay awake" toggle: blocks both the X11 screensaver/DPMS timeout
// (screen blanking/power-off, via xset) and xautolock's idle-lock timer
// (via its -disable/-enable IPC to the already-running instance - these are
// otherwise fully independent, since xautolock tracks idle time through the
// X Screen Saver *extension*, which keeps counting regardless of whether
// xset's own screensaver/DPMS blanking is on or off). Without also pausing
// xautolock, turning this on to e.g. watch a video without touching the
// mouse would still get the screen locked out from under it after xautolock's
// timeout, defeating the point.
// State lives in the StayAwakeState singleton (not a local property) since
// this is all global-to-the-X-session state, but Bar.qml creates one
// instance of this per monitor.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        Text {
            text: ""
            color: StayAwakeState.awake ? root.activeColor : root.textColor
            font.pixelSize: 13
        }

        Text {
            text: StayAwakeState.awake ? "awake" : ""
            color: root.activeColor
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            StayAwakeState.awake = !StayAwakeState.awake
            if (StayAwakeState.awake) {
                Quickshell.execDetached(["xset", "s", "off", "-dpms"])
                Quickshell.execDetached(["xautolock", "-disable"])
            } else {
                Quickshell.execDetached(["xset", "s", "on", "+dpms"])
                Quickshell.execDetached(["xautolock", "-enable"])
            }
        }
    }
}
