import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bar icon for Bluetooth: colored when the default adapter is powered on,
// muted otherwise. Clicking opens BluetoothPanel.qml (the actual power
// toggle, scan, and device list live there, not here) rather than toggling
// power directly from the bar - unlike StayAwake/NightLight, there's real
// per-device state to manage, not just one on/off flag.
//
// `toggle()` is exposed (see StayAwake.qml's header comment for the full
// reasoning) so ControlCenter.qml's quick-toggle tiles can drive this from
// their own full-tile MouseArea instead of just this component's small
// icon; `clickable: false` disables this component's own internal
// MouseArea for that case, avoiding opening-then-immediately-reclosing
// the panel from a single click.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    property bool clickable: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool poweredOn: !!(root.adapter && root.adapter.enabled)

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    function toggle() {
        BluetoothPanelState.visible = !BluetoothPanelState.visible
    }

    NText {
        id: icon
        text: ""
        color: root.poweredOn ? root.activeColor : root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        onClicked: root.toggle()
    }
}
