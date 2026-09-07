pragma Singleton
import QtQuick

// Shared state for the transient volume/brightness popup (OSD.qml), driven
// externally over Quickshell's IPC by the XF86Audio*/XF86MonBrightness*
// keybinds in zaris.conf (see osd-volume.sh):
//   qs ipc call osd volume <0-100> <true|false muted>
//   qs ipc call osd brightness <0-100>
// Auto-hides itself a bit after the last call, so holding a key down keeps
// it on screen and releasing it lets it fade after a short pause.
QtObject {
    id: root

    property bool visible: false
    property string kind: "volume" // "volume" or "brightness"
    property real level: 0 // 0.0 - 1.0
    property bool muted: false

    property Timer hideTimer: Timer {
        interval: 1500
        onTriggered: root.visible = false
    }

    function show(newKind, percent, isMuted) {
        root.kind = newKind
        root.level = Math.max(0, Math.min(100, percent)) / 100
        root.muted = !!isMuted
        root.visible = true
        hideTimer.restart()
    }
}
