pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared state for the transient volume/brightness popup (OSD.qml), driven
// externally over Quickshell's IPC by the XF86Audio*/XF86MonBrightness*
// keybinds in zaris.conf (see osd-volume.sh):
//   qs ipc call osd volume <0-100> <true|false muted>
//   qs ipc call osd brightness <0-100>
// Auto-hides itself a bit after the last call, so holding a key down keeps
// it on screen and releasing it lets it fade after a short pause.
//
// `enabled`/`hideDelayMs` are new for Settings' own OSD tab - previously
// this had no persisted settings at all (hideTimer.interval was a bare
// hardcoded 1500). Same FileView+JsonAdapter pattern as every other
// *Config.qml.
QtObject {
    id: root

    property bool visible: false
    property string kind: "volume" // "volume" or "brightness"
    property real level: 0 // 0.0 - 1.0
    property bool muted: false

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/osd.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            property bool enabled: true
            property int hideDelayMs: 1500
        }
    }

    readonly property bool enabled: configFile.adapter.enabled
    readonly property int hideDelayMs: configFile.adapter.hideDelayMs

    function setEnabled(val) {
        configFile.adapter.enabled = val
    }

    function setHideDelayMs(val) {
        configFile.adapter.hideDelayMs = val
    }

    property Timer hideTimer: Timer {
        interval: root.hideDelayMs
        onTriggered: root.visible = false
    }

    // Suppressed entirely when disabled - the IPC calls this is driven by
    // (osd-volume.sh, XF86MonBrightness* keybinds) still fire and still do
    // their real job (actually changing volume/brightness); this only
    // gates whether the on-screen popup itself appears.
    function show(newKind, percent, isMuted) {
        if (!root.enabled)
            return
        root.kind = newKind
        root.level = Math.max(0, Math.min(100, percent)) / 100
        root.muted = !!isMuted
        root.visible = true
        hideTimer.restart()
    }
}
