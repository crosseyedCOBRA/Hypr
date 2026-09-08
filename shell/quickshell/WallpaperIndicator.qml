import QtQuick
import Quickshell

// Bar icon for the wallpaper picker - click opens WallpaperPickerPanel.qml.
// Same "icon opens a panel" pattern as ClipboardIndicator.qml/
// BluetoothIndicator.qml.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: ""
        color: WallpaperService.rotationEnabled ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        onClicked: WallpaperPickerPanelState.visible = !WallpaperPickerPanelState.visible
    }
}
