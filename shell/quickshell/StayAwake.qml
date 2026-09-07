import QtQuick
import Quickshell

// Manual "stay awake" toggle: `xset s off -dpms` blocks the X11
// screensaver/DPMS timeout (screen blanking/power-off) AND the idle lock,
// since the idle lock now runs via xss-lock (see zaris.conf), which fires
// off the same X screensaver extension's activation event -- disabling the
// extension entirely means it can never send that event, so unlike the
// project's earlier xautolock-based setup, no separate enable/disable IPC
// to the locker is needed here anymore.
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
            } else {
                Quickshell.execDetached(["xset", "s", "on", "+dpms"])
            }
        }
    }
}
