pragma Singleton
import QtQuick

// Shared visibility flag for the launcher popup, so both the IpcHandler
// (external `qs ipc call launcher toggle`) and the bar's logo click can
// drive the same window.
//
// `anchorItem` is only used in BarConfig.layoutMode "taskbar" - the bar's
// own taskbar-mode launcher icon (set by Bar.qml right before toggling
// visible), which Launcher.qml's taskbar-mode PopupWindow variant anchors
// under, similar to how SettingsState.targetItem/ControlCenterState.barItem
// work for Settings.qml. Unused (stays null) in "statusbar" mode, where the
// launcher is still a plain centered FloatingWindow as it always has been.
QtObject {
    property bool visible: false
    property Item anchorItem: null
}
