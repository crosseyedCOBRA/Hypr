import QtQuick
import Quickshell

// Bar icon for notification history - left-click opens
// NotificationHistoryPanel.qml (same "icon opens a panel" pattern as
// ClipboardIndicator.qml/BluetoothIndicator.qml, since there's a real
// list/filter/delete UI behind it, not just a toggle). Right-click toggles
// Do Not Disturb - moved here from being its own Control Center tile (see
// ROADMAP.md's own writeup) per explicit request, the same
// left-click-opens/right-click-toggles split VolumeControl.qml already
// uses for its own panel+mute pair. The icon itself doubles as the DND
// state indicator (swaps to Dnd.qml's own bell-slash glyph while paused;
// its "unread notifications" color logic is otherwise unaffected) rather
// than adding a second icon, since there's nowhere else in the bar DND's
// state is visible anymore now that its tile is gone.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property color dndColor: "white"

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: DndState.paused ? "" : ""
        color: DndState.paused ? root.dndColor : (NotificationHistoryService.notifications.length > 0 ? root.activeColor : root.textColor)
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                NotificationHistoryPanelState.anchorItem = root
                NotificationHistoryPanelState.visible = !NotificationHistoryPanelState.visible
            } else if (mouse.button === Qt.RightButton) {
                DndState.toggle()
            }
        }
    }
}
