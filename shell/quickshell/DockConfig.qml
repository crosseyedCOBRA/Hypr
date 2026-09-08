pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Dock config, backed by ~/.config/quickshell/dock.json. Same pattern as
// ModulesConfig.qml/modules.json: hand-editable directly, or through
// Settings.qml - both take effect live, no qs restart needed.
//
//   "enabled": true/false - false fully deactivates the dock (no wmctrl
//                            polling running), not just hides it.
//   "mode": "reserved" | "floating"
//                          - "reserved": a PanelWindow like the bar, which
//                            reserves screen space (windows tile around it).
//                          - "floating": a plain floating window anchored via
//                            one of the WM's own `*center` windowrules
//                            (matched against Dock.qml's own dynamic window
//                            title, "Dock-<position>" - see Dock.qml's own
//                            comment for why the WM-side rule has to be
//                            title-matched rather than reading this file
//                            directly), which does NOT reserve space.
//   "position": "top" | "bottom" | "left" | "right"
//                          - which edge of the monitor the dock sits on.
//                            top/bottom lay icons out in a Row, left/right
//                            in a Column - see Dock.qml/DockIcons.qml.
//   "launcherPosition": "start" | "end"
//                          - which end of the dock's own strip the static
//                            launcher icon sits at, deliberately independent
//                            of "position": "start" always means the
//                            top/left-most slot along whichever axis the
//                            dock is actually laid out on, so it stays a
//                            meaningful choice for a vertical dock too
//                            (unlike a literal "left"/"right" label would).
//   "screens": "all" | "primary" | ["Output-Name", ...]
//                          - same shape and meaning as ModulesConfig.qml's
//                            own per-module `screens` field. "primary"
//                            matches Quickshell.screens[0]; an array matches
//                            by exact RandR output name (`xrandr` names,
//                            e.g. "DisplayPort-1").
//   "backgroundOpacity": 0.0-1.0 - the dock panel's background alpha.
//   "backgroundColor": "#rrggbb" - the dock panel's background color.
//   "autoHide": true/false - only meaningful in "floating" mode ("reserved"
//                            is always fully visible, same as the bar).
//                            false (default): the dock is always shown.
//                            true: the dock stays hidden until the pointer
//                            hovers a small trigger strip left sitting at
//                            the same edge/position, then hides again a
//                            short delay after the pointer leaves it - see
//                            Dock.qml's own comment for why this is a
//                            separate small always-present window rather
//                            than the dock itself shrinking/growing.
//   "pinned": [id, ...]    - desktop-entry IDs (DesktopEntries.applications
//                            entries' `.id`), in display order. Pinned via
//                            right-click on a Launcher result.
QtObject {
    id: root

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/dock.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property bool enabled: true
            property string mode: "reserved"
            property string position: "bottom"
            property string launcherPosition: "start"
            property var screens: "primary"
            property real backgroundOpacity: 0.85
            property string backgroundColor: "#0c0b1a"
            property bool autoHide: false
            property var pinned: []
        }
    }

    readonly property bool enabled: configFile.adapter.enabled !== false
    readonly property string mode: configFile.adapter.mode === "floating" ? "floating" : "reserved"
    readonly property string position: {
        const p = configFile.adapter.position
        return (p === "top" || p === "left" || p === "right") ? p : "bottom"
    }
    readonly property bool isVertical: root.position === "left" || root.position === "right"
    readonly property string launcherPosition: configFile.adapter.launcherPosition === "end" ? "end" : "start"
    readonly property real backgroundOpacity: {
        const o = configFile.adapter.backgroundOpacity
        return (typeof o === "number" && o >= 0 && o <= 1) ? o : 0.85
    }
    readonly property string backgroundColor: configFile.adapter.backgroundColor || "#0c0b1a"
    readonly property bool autoHide: configFile.adapter.autoHide === true
    readonly property var pinned: configFile.adapter.pinned || []

    function setEnabled(val) {
        configFile.adapter.enabled = val
    }

    function setMode(val) {
        configFile.adapter.mode = val
    }

    function setPosition(val) {
        configFile.adapter.position = val
    }

    function setLauncherPosition(val) {
        configFile.adapter.launcherPosition = val
    }

    function setBackgroundOpacity(val) {
        configFile.adapter.backgroundOpacity = val
    }

    function setBackgroundColor(val) {
        configFile.adapter.backgroundColor = val
    }

    function setAutoHide(val) {
        configFile.adapter.autoHide = val
    }

    // Same shape/semantics as ModulesConfig.qml's own _screenMatches -
    // "primary" matches Quickshell.screens[0], an array matches by exact
    // RandR output name, "all" (or anything else unrecognized) matches
    // everything. Dock.qml calls this per-monitor-instance, same pattern
    // as Bar.qml's own per-module `showInBar`/`showInTray` checks.
    function screenMatches(screen) {
        const s = configFile.adapter.screens
        if (s === undefined || s === "all")
            return true
        if (s === "primary")
            return screen === Quickshell.screens[0]
        if (Array.isArray(s))
            return !!(screen && s.indexOf(screen.name) !== -1)
        return true
    }

    function setScreens(val) {
        configFile.adapter.screens = val
    }

    function isPinned(id) {
        return root.pinned.indexOf(id) !== -1
    }

    function pin(id) {
        if (root.isPinned(id))
            return
        configFile.adapter.pinned = root.pinned.concat([id])
    }

    function unpin(id) {
        configFile.adapter.pinned = root.pinned.filter(function (p) { return p !== id })
    }

    function togglePin(id) {
        if (!id)
            return
        if (root.isPinned(id))
            root.unpin(id)
        else
            root.pin(id)
    }

    // Reorders a pinned app to newIndex (drag-and-drop reordering in
    // DockIcons.qml, clamped there to only ever move among other pinned
    // apps). No-op for an id that isn't actually pinned.
    function reorderPinned(id, newIndex) {
        if (!id || !root.isPinned(id))
            return
        const current = root.pinned.slice()
        const oldIndex = current.indexOf(id)
        current.splice(oldIndex, 1)
        current.splice(Math.max(0, Math.min(newIndex, current.length)), 0, id)
        configFile.adapter.pinned = current
    }
}
