import QtQuick
import Quickshell

// Manual "do not disturb" toggle for dunst, via `dunstctl set-paused
// toggle` - same simple on/off pattern as StayAwake.qml/NightLight.qml.
// Fulfills the Do Not Disturb quick-toggle idea from Noctalia v5's
// Control Center (see ROADMAP.md's Phase 3 section) - not a port of
// anything, dunst already has its own real pause mechanism
// (`dunstctl set-paused`/`is-paused`, confirmed via `dunstctl --help`),
// so this is just a thin bar-icon wrapper around a command dunst itself
// already provides, the same relationship `NightLight.qml` has with
// `redshift`.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        NText {
            text: DndState.paused ? "" : ""
            color: DndState.paused ? root.activeColor : root.textColor
            pointSize: Style.fontSizeL
        }

        NText {
            text: DndState.paused ? "dnd" : ""
            color: root.activeColor
            pointSize: Style.fontSizeL
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            DndState.paused = !DndState.paused
            Quickshell.execDetached(["dunstctl", "set-paused", "toggle"])
        }
    }
}
