pragma Singleton
import QtQuick

// Shared visibility flag for BluetoothPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState - the bar icon
// (BluetoothIndicator.qml) and the tray flyout's copy of it both need to
// open the same one panel.
QtObject {
    property bool visible: false
}
