pragma Singleton
import QtQuick

// Shared open/closed state for ClipboardHistoryPanel.qml, same pattern as
// SettingsState/OverflowState/PinDialogState/BluetoothPanelState.
QtObject {
    property bool visible: false
}
