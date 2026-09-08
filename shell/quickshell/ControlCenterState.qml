pragma Singleton
import QtQuick

// Shared open/closed state for the Control Center flyout (ControlCenter.qml),
// plus which monitor's chevron opened it - so the panel shows only the
// tray modules configured for that specific screen.
//
// `barItem` is the bar's own full-width background Rectangle (Bar.qml's
// barSurface) on whichever monitor was clicked - set alongside `panel` at
// the same click. Settings.qml anchors its own PopupWindow here (via
// SettingsState.targetItem, set to this when the gear button inside
// Control Center is clicked) rather than to the gear button itself - the
// gear button lives inside Control Center's own window, which closes at
// the same time Settings opens, and a PopupWindow can't anchor to a target
// whose own window has gone invisible. The bar itself never closes, so
// this stays a valid anchor regardless of Control Center's own state.
// Anchoring to the full-width bar surface (not the launcher icon) also lets
// Settings center itself under the whole bar rather than sitting off to one
// side under a small icon.
QtObject {
    property bool visible: false
    property var panel: null
    property Item barItem: null
}
