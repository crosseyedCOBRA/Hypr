pragma Singleton
import QtQuick

// Shared open/closed state for NotificationHistoryPanel.qml, same pattern
// as SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState/WallpaperPickerPanelState.
QtObject {
    property bool visible: false
}
