import QtQuick
import Quickshell

// Bar icon for clipboard history - click opens ClipboardHistoryPanel.qml.
// Same "icon opens a panel" pattern as BluetoothIndicator.qml, since there's
// real list/search UI behind it, not just a toggle.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: ""
        color: ClipboardHistoryService.items.length > 0 ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        onClicked: ClipboardHistoryPanelState.visible = !ClipboardHistoryPanelState.visible
    }
}
