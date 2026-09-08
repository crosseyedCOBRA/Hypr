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
//
// `toggle()` is exposed (not just an inline onClicked body) so a container
// with a larger hit region than this component's own small icon+label -
// ControlCenter.qml's quick-toggle tiles, specifically - can drive the
// exact same action from its own full-tile MouseArea. `clickable: false`
// disables this component's own internal MouseArea for that case, so a
// click isn't handled twice (toggled, then immediately toggled back).
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property bool clickable: true

    function toggle() {
        StayAwakeState.awake = !StayAwakeState.awake
        if (StayAwakeState.awake) {
            Quickshell.execDetached(["xset", "s", "off", "-dpms"])
        } else {
            Quickshell.execDetached(["xset", "s", "on", "+dpms"])
        }
    }

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        NText {
            text: ""
            color: StayAwakeState.awake ? root.activeColor : root.textColor
            pointSize: Style.fontSizeL
        }

        NText {
            text: StayAwakeState.awake ? "awake" : ""
            color: root.activeColor
            pointSize: Style.fontSizeL
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        onClicked: root.toggle()
    }
}
