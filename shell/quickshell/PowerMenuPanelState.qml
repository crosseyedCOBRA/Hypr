pragma Singleton
import QtQuick

// Shared open/closed state for PowerMenuPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState/WallpaperPickerPanelState/AvatarPickerPanelState.
QtObject {
    property bool visible: false
}
