pragma Singleton
import QtQuick

// Shared open/closed state for WallpaperPickerPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState.
QtObject {
    property bool visible: false
}
