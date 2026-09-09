pragma Singleton
import QtQuick

// Shared open/closed state for AudioMixerPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// NotificationHistoryPanelState. `anchorItem` is the bar's VolumeControl
// icon that was actually clicked - needed since the panel anchors to the
// bar (PopupWindow, same as NotificationHistoryPanel.qml) rather than
// centering on screen, and a multi-monitor setup has one icon per bar but
// only one shared panel instance.
QtObject {
    property bool visible: false
    property Item anchorItem: null
}
