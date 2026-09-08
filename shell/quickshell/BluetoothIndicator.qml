import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bar icon for Bluetooth: colored when the default adapter is powered on,
// muted otherwise. Clicking opens BluetoothPanel.qml (the actual power
// toggle, scan, and device list live there, not here) rather than toggling
// power directly from the bar - unlike StayAwake/NightLight, there's real
// per-device state to manage, not just one on/off flag.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool poweredOn: !!(root.adapter && root.adapter.enabled)

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: ""
        color: root.poweredOn ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        onClicked: BluetoothPanelState.visible = !BluetoothPanelState.visible
    }
}
