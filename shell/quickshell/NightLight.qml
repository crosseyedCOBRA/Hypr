import QtQuick
import Quickshell

// Manual night-light toggle: applies/resets a warm color-temperature
// override via `redshift -O <temp>` (one-shot mode - adjusts the X server's
// RandR gamma ramps and exits immediately, no daemon process to keep
// running) / `redshift -x` (resets the ramps back to normal). Same
// reasoning as StayAwake.qml for keeping state in a shared singleton rather
// than a local property: Bar.qml creates one instance per monitor, but the
// gamma-ramp override is global to the X server, not per-monitor.
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
            text: ""
            color: NightLightState.active ? root.activeColor : root.textColor
            font.pixelSize: 13
        }

        Text {
            text: NightLightState.active ? "night" : ""
            color: root.activeColor
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            NightLightState.active = !NightLightState.active
            if (NightLightState.active) {
                Quickshell.execDetached(["redshift", "-O", String(NightLightService.nightTemp)])
            } else {
                Quickshell.execDetached(["redshift", "-x"])
            }
        }
    }
}
