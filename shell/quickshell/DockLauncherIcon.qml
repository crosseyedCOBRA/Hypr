import QtQuick

// Static launcher icon, always the leftmost item in the dock (Dock.qml) --
// unlike the rest of the row (DockIcons.qml), this isn't part of
// DockConfig's pinned/running list, it's a fixed entry point to the exact
// same launcher the bar's own logo opens (Bar.qml). Now genuinely the same
// *icon* too, not just the same action - this used to hardcode its own
// separate path (zaris-logo.png) regardless of whatever BarConfig.
// launcherIcon was actually set to, so customizing the bar's launcher icon
// via Settings silently left the dock showing a different image. Reported
// live as wanting the bar's own default to match what the dock already
// showed - fixed the other direction instead (dock now follows the bar's
// config, not a second hardcoded default) so the two can never drift again.
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
        // See Bar.qml's own launcher icon Image for why - same fix, same
        // reasoning (a large custom user image reading as pixelated
        // without this).
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        source: "file://" + BarConfig.launcherIcon
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: LauncherState.visible = !LauncherState.visible
    }
}
