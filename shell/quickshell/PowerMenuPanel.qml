import QtQuick
import Quickshell

// Power menu popup - replaces the Control Center power button's old
// behavior (launching powermenu.sh, a rofi-based dmenu list) with a real
// themed popup matching the reference screenshot: 5 equal-width square
// tiles in one centered row (Lock/Suspend/Reboot/Logout/Shutdown, each a
// large icon over a label, numbered 1-5 in their own top-right corner -
// the numbering is purely visual here, matching the reference, not wired
// to real number-key shortcuts, since this WM has no existing mechanism
// for a popup-scoped keybind separate from its own global keybind table).
// Shutdown alone gets the warning-red accent, the other four stay neutral.
//
// Reuses powermenu.sh's own exact commands for each action (i3lock for
// Lock, `pkill zaris` for Logout, loginctl suspend/reboot/poweroff for the
// rest) rather than re-deriving them, so this stays in sync with whatever
// that script already does - powermenu.sh itself is left in place
// untouched (still reachable directly, e.g. from a terminal or a keybind),
// this panel is just a second, richer entry point to the same actions.
// No confirmation step before acting - matches powermenu.sh's own
// immediate-on-selection behavior (a rofi dmenu list has no confirmation
// step either), not new friction this panel adds.
FloatingWindow {
    id: panel

    visible: PowerMenuPanelState.visible
    title: "Power Menu"

    implicitWidth: 520
    implicitHeight: 150

    function act(command) {
        Quickshell.execDetached(command)
        PowerMenuPanelState.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            z: 1
            baseSize: 24
            icon: ""
            tooltipText: "Close"
            onClicked: PowerMenuPanelState.visible = false
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: [
                    { key: "1", label: "Lock", icon: "", danger: false, command: ["i3lock"] },
                    { key: "2", label: "Suspend", icon: "", danger: false, command: ["loginctl", "suspend"] },
                    { key: "3", label: "Reboot", icon: "", danger: false, command: ["loginctl", "reboot"] },
                    { key: "4", label: "Logout", icon: "", danger: false, command: ["pkill", "zaris"] },
                    { key: "5", label: "Shutdown", icon: "", danger: true, command: ["loginctl", "poweroff"] }
                ]

                Rectangle {
                    id: tile
                    required property var modelData
                    width: 90
                    height: 90
                    radius: Style.radiusS
                    color: tileArea.containsMouse ? Colors.pillActive : Colors.pill
                    border.width: tile.modelData.danger ? 1 : 0
                    border.color: Colors.red

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }

                    NText {
                        text: tile.modelData.key
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        color: Colors.textMuted
                        pointSize: Style.fontSizeXS
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        NIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            icon: tile.modelData.icon
                            color: tile.modelData.danger ? Colors.red : Colors.text
                            pointSize: Style.fontSizeXXL
                        }

                        NText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            color: tile.modelData.danger ? Colors.red : Colors.text
                            pointSize: Style.fontSizeS
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.act(tile.modelData.command)
                    }
                }
            }
        }
    }
}
