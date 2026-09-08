pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bar module config, backed by ~/.config/quickshell/modules.json. Hand-editable
// directly (like hypr.conf), or through Settings.qml - both take effect live,
// no qs restart needed, and stay in sync (the settings window writes through
// this same FileView, so a hand edit while it's open is picked up too).
//
// Each entry:
//   "enabled": true/false  - false fully deactivates the module (no polling/
//                             timers running anywhere), not just hides it.
//   "screens": "all" | "primary" | ["Output-Name", ...]
//                           - "primary" matches Quickshell.screens[0]; an
//                             array matches exact xrandr/RandR output names
//                             (see `xrandr` output, e.g. "DisplayPort-1").
//                             Only applies to showInBar() - the bar really
//                             is per-monitor (Bar.qml instantiates one per
//                             screen), so this avoids e.g. duplicating
//                             kernel/network across every monitor's bar.
//                             showInTray() ignores it entirely: the Control
//                             Center is one single global window, not
//                             per-monitor, so a module scoped "primary"
//                             would otherwise vanish from it entirely
//                             whenever it's opened from a non-primary
//                             monitor's chevron - confusing for something
//                             with no other per-monitor meaning.
//   "tray": true/false     - false (default): shown directly in the bar.
//                             true: still active, but tucked into the
//                             overflow flyout (the "..." icon) instead of
//                             taking up space in the bar itself.
QtObject {
    id: root

    readonly property var moduleIds: ["kernel", "cpu", "cpuTemp", "gpuTemp", "network", "wifi", "volume", "stayAwake", "nightLight", "dnd", "bluetooth", "mediaPlayer", "clipboard", "wallpaper", "battery"]

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/modules.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property var kernel: ({ enabled: true, screens: "primary", tray: false })
            property var cpu: ({ enabled: true, screens: "all", tray: false })
            property var cpuTemp: ({ enabled: true, screens: "all", tray: false })
            property var gpuTemp: ({ enabled: true, screens: "all", tray: false })
            property var network: ({ enabled: true, screens: "primary", tray: true })
            property var wifi: ({ enabled: true, screens: "all", tray: true })
            property var volume: ({ enabled: true, screens: "all", tray: false })
            property var stayAwake: ({ enabled: true, screens: "all", tray: false })
            property var nightLight: ({ enabled: true, screens: "all", tray: false })
            property var dnd: ({ enabled: true, screens: "all", tray: true })
            property var bluetooth: ({ enabled: true, screens: "all", tray: false })
            property var mediaPlayer: ({ enabled: true, screens: "all", tray: false })
            property var clipboard: ({ enabled: true, screens: "all", tray: true })
            property var wallpaper: ({ enabled: true, screens: "all", tray: true })
            property var battery: ({ enabled: true, screens: "all", tray: true })
        }
    }

    function _entry(id) {
        return configFile.adapter[id] || { enabled: true, screens: "all", tray: false }
    }

    function _screenMatches(id, panel) {
        const s = root._entry(id).screens
        if (s === undefined || s === "all")
            return true
        if (s === "primary")
            return !!(panel && panel.isPrimary)
        if (Array.isArray(s))
            return !!(panel && panel.modelData && s.indexOf(panel.modelData.name) !== -1)
        return true
    }

    function showInBar(id, panel) {
        const e = root._entry(id)
        return e.enabled !== false && !e.tray && root._screenMatches(id, panel)
    }

    function showInTray(id, panel) {
        const e = root._entry(id)
        return e.enabled !== false && !!e.tray
    }

    function anyTrayVisible(panel) {
        return root.moduleIds.some(function (id) { return root.showInTray(id, panel) })
    }

    // Setters used by Settings.qml. Each does a full reassignment of the
    // entry (not an in-place mutation of the nested object) - QML only
    // notices property *assignment*, so `configFile.adapter[id].enabled =
    // x` would silently fail to trigger the write-back or any bindings.
    function setEnabled(id, val) {
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { enabled: val })
    }

    function setTray(id, val) {
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { tray: val })
    }

    function setScreens(id, val) {
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { screens: val })
    }
}
