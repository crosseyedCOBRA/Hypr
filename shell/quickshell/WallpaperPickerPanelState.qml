pragma Singleton
import QtQuick

// Shared open/closed state for WallpaperPickerPanel.qml, same pattern as
// SettingsState/OverflowState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState.
QtObject {
    property bool visible: false
}
