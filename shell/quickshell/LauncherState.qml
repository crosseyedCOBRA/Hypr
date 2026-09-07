pragma Singleton
import QtQuick

// Shared visibility flag for the launcher popup, so both the IpcHandler
// (external `qs ipc call launcher toggle`) and the bar's logo click can
// drive the same window.
QtObject {
    property bool visible: false
}
