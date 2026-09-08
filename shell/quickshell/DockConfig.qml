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
//                            reserves screen space (windows tile above it).
//                          - "floating": a plain floating window anchored to
//                            the bottom-center of the monitor via the
//                            `bottomcenter` windowrule, which does NOT
//                            reserve space - windows can tile underneath it.
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
            property var pinned: []
        }
    }

    readonly property bool enabled: configFile.adapter.enabled !== false
    readonly property string mode: configFile.adapter.mode === "floating" ? "floating" : "reserved"
    readonly property var pinned: configFile.adapter.pinned || []

    function setEnabled(val) {
        configFile.adapter.enabled = val
    }

    function setMode(val) {
        configFile.adapter.mode = val
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
