pragma Singleton
import QtQuick

// Shared open/closed state for NotificationHistoryPanel.qml, same pattern
// as SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState/WallpaperPickerPanelState.
//
// anchorItem - the bar's NotificationIndicator icon that was actually
// clicked, set by NotificationIndicator.qml right before toggling visible.
// Needed now that the panel anchors to the bar (PopupWindow) instead of
// centering on screen via a WM windowrule - same "retarget per click"
// approach LauncherState.anchorItem/ControlCenterState.barItem already use,
// since a multi-monitor setup has one indicator per bar but only one
// shared panel instance.
QtObject {
    property bool visible: false
    property Item anchorItem: null
}
