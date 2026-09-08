import QtQuick

// Reusable animated toggle switch - adapted from Noctalia's NToggle.qml
// (MIT licensed, github.com/noctalia-dev/noctalia @ v4.7.7 - see README.md's
// "Third-party code" section), stripped down to just the switch itself:
// their version bundles an optional label/description/icon prefix (NLabel)
// and a "changed from default" indicator tooltip (I18n-driven) that Zaris
// has no equivalent concepts for - every existing call site already places
// its own separate label Text beside the switch, so keeping this a plain
// switch matches that convention rather than replacing it.
//
// Same visual dimensions/colors as the toggle Rectangle block that had been
// hand-copied (unanimated, static) across Settings.qml/BluetoothPanel.qml/
// the dock and module configs - this is a drop-in visual upgrade (adds a
// smooth color/position transition and a pointing-hand cursor on hover),
// not a redesign, so swapping existing usages over is low-risk.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool newChecked)

    implicitWidth: 44
    implicitHeight: 22
    radius: height / 2
    color: checked ? Colors.pillActive : Colors.pill
    border.color: Colors.textMuted
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: Style.animationFast }
    }

    Rectangle {
        width: 16
        height: 16
        radius: width / 2
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: Colors.text

        Behavior on x {
            NumberAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
