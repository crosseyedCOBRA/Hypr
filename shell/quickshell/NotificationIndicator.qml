import QtQuick
import Quickshell

// Bar icon for notification history - click opens
// NotificationHistoryPanel.qml. Same "icon opens a panel" pattern as
// ClipboardIndicator.qml/BluetoothIndicator.qml, since there's a real
// list/filter/delete UI behind it, not just a toggle.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: ""
        color: NotificationHistoryService.notifications.length > 0 ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        onClicked: NotificationHistoryPanelState.visible = !NotificationHistoryPanelState.visible
    }
}
