pragma Singleton
import QtQuick

// Shared open/closed state for the bar module settings window (Settings.qml).
// `targetItem` is the Item Settings.qml's PopupWindow anchors under - set
// right before opening it (currently always ControlCenterState.barItem, the
// bar's own full-width background surface - Control Center's gear button is
// the only way Settings ever opens, but Control Center closes itself at the
// same moment, so Settings anchors to the bar surface instead of the gear
// button, which wouldn't stay valid), the same "one shared instance,
// retargeted per interaction" approach CalendarFlyoutState.qml already uses
// for the clock.
QtObject {
    property bool visible: false
    property Item targetItem: null

    // Set right before `visible = true` by anything that wants Settings to
    // open directly to a specific category id (e.g. AudioMixerPanel.qml's
    // gear button jumping to "audio") rather than whatever `activeCategory`
    // was last left on. Settings.qml consumes and clears this itself the
    // moment it becomes visible - a plain open (Control Center's gear
    // button) never touches this, so Settings keeps opening to its last
    // category as before in that case.
    property string requestedCategory: ""
}
