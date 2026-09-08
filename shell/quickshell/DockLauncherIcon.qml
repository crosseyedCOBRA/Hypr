import QtQuick
import Quickshell

// Static launcher icon, always the leftmost item in the dock (Dock.qml) --
// unlike the rest of the row (DockIcons.qml), this isn't part of
// DockConfig's pinned/running list, it's a fixed entry point to the exact
// same launcher the bar's own logo opens (Bar.qml).
Item {
    id: root

    width: 44
    height: 44

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: hoverArea.containsMouse ? Colors.pillActive : "transparent"
    }

    Image {
        anchors.centerIn: parent
        width: 32
        height: 32
        fillMode: Image.PreserveAspectFit
        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/zaris-logo.png"
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: LauncherState.visible = !LauncherState.visible
    }
}
