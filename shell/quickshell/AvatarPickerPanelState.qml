pragma Singleton
import QtQuick

// Shared open/closed state for AvatarPickerPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState/WallpaperPickerPanelState/
// NotificationHistoryPanelState.
//
// `version` is not just open/closed state - it's a cache-busting counter.
// ControlCenter.qml's avatar Image loads `~/.face` by a fixed path; QML's
// image cache keys on the URL string, not the file's actual contents, so
// overwriting `~/.face` in place (AvatarPickerPanel.qml's setAvatar())
// wouldn't be picked up by an already-running Control Center without
// something forcing a fresh load. Bumped once per successful set;
// ControlCenter.qml appends it to its own `~/.face` source URL as a query
// string, which is enough to make QML treat it as a different image and
// re-fetch even though it resolves to the exact same file.
QtObject {
    property bool visible: false
    property int version: 0
}
