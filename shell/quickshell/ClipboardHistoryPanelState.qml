pragma Singleton
import QtQuick

// Shared open/closed state for ClipboardHistoryPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState.
QtObject {
    property bool visible: false
}
