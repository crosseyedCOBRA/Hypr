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
//   "section": "left" | "center" | "right" (default "right") - which of
//                             the bar's three zones a bar-shown module
//                             (tray: false) renders in. Ignored for
//                             tray-shown modules (Control Center is one
//                             flat list, not sectioned) and ignored
//                             entirely in the bar's "taskbar" layout mode,
//                             whose left/center are already spoken for by
//                             the embedded dock/workspaces - see
//                             Bar.qml's own comment on that boundary.
//   "order": number         - sort key within a module's destination
//                             (its bar section, or the Control Center
//                             list) - lower sorts first. Ties break by
//                             moduleIds's own array order, matching this
//                             file's previous (pre-Settings-driven)
//                             hardcoded rendering order.
QtObject {
    id: root

    readonly property var moduleIds: ["kernel", "cpu", "cpuTemp", "gpuTemp", "network", "wifi", "volume", "stayAwake", "nightLight", "dnd", "bluetooth", "mediaPlayer", "clipboard", "wallpaper", "battery", "notifications"]

    // The subset Settings' new "Bar Modules" tab lets you add/reorder -
    // every id above except mediaPlayer, which has no bar-side rendering
    // at all (Control Center's media card replaced Bar.qml's own
    // MediaWidget - see BarStatusModules.qml's own comment), so adding it
    // to a bar section would silently render nothing.
    readonly property var barModuleIds: root.moduleIds.filter(function (id) { return id !== "mediaPlayer" })

    // The subset Settings' new "Control Center" tab lets you add/reorder -
    // every module in Control Center's main quick-toggle grid, which
    // renders as the same uniform tile shape (a Column: icon or toggle
    // component, then a label, with a MouseArea over the whole tile) -
    // checked each one's actual QML shape and grid membership directly
    // rather than assumed, since a couple (stayAwake, nightLight) default
    // to hidden (tray: false) and were easy to miss at a glance.
    // Deliberately excludes: wallpaper (a uniform tile shape too, but
    // lives in a second, visually separate Grid alongside the
    // Screenshot tile - which has no modules.json entry at all - rather
    // than this main one; interleaving it into this list would break
    // that deliberate two-grid grouping), kernel/cpu/cpuTemp/gpuTemp/
    // battery (gauges/a text line, a different fixed layout block
    // entirely), volume (the Audio section, sliders not a toggle tile),
    // and mediaPlayer (the media card) - none of those are interchangeable
    // same-shaped chips the way these seven are, so a generic reorder
    // wouldn't correctly relocate them in Control Center's actual layout.
    // The power-profile tile has no modules.json entry either and stays
    // fixed first in this grid regardless of how these seven are arranged.
    // A real reorderable surface for the excluded set needs the separate,
    // not-yet-designed Control Center layout work (see ROADMAP.md's own
    // still-open items for that).
    readonly property var trayModuleIds: ["stayAwake", "dnd", "nightLight", "network", "wifi", "clipboard", "bluetooth"]

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/modules.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            // Off by default in the bar (per explicit user request) -
            // Control Center now has its own always-visible "Running
            // Kernel" section (ControlCenter.qml) independent of this
            // module entirely, so the kernel version is still visible
            // somewhere out of the box even with this disabled. Still a
            // real, re-enableable bar module - toggle "Enabled" in
            // Settings' Modules tab to bring it back into the bar too.
            property var kernel: ({ enabled: false, screens: "primary", tray: false })
            property var cpu: ({ enabled: true, screens: "all", tray: false })
            property var cpuTemp: ({ enabled: true, screens: "all", tray: false })
            property var gpuTemp: ({ enabled: true, screens: "all", tray: false })
            property var network: ({ enabled: true, screens: "primary", tray: true })
            property var wifi: ({ enabled: true, screens: "all", tray: true })
            property var volume: ({ enabled: true, screens: "all", tray: true })
            property var stayAwake: ({ enabled: true, screens: "all", tray: false })
            property var nightLight: ({ enabled: true, screens: "all", tray: false })
            property var dnd: ({ enabled: true, screens: "all", tray: true })
            property var bluetooth: ({ enabled: true, screens: "all", tray: false })
            property var mediaPlayer: ({ enabled: true, screens: "all", tray: true })
            property var clipboard: ({ enabled: true, screens: "all", tray: true })
            property var notifications: ({ enabled: true, screens: "all", tray: false })
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

    function section(id) {
        const s = root._entry(id).section
        return (s === "left" || s === "center" || s === "right") ? s : "right"
    }

    // Falls back to the id's own position in moduleIds (the file's
    // original hardcoded render order) when no explicit order was ever
    // set - new modules.json files, or entries never touched by the new
    // Settings tabs, keep rendering in exactly the order they always did.
    function order(id) {
        const o = root._entry(id).order
        if (typeof o === "number")
            return o
        return root.moduleIds.indexOf(id)
    }

    function _sortedByOrder(ids) {
        return ids.slice().sort(function (a, b) { return root.order(a) - root.order(b) })
    }

    // Bar-shown (tray: false), enabled, screen-matched modules assigned to
    // one of the bar's three zones, in their configured order - the actual
    // data BarStatusModules.qml's per-section Repeater renders from.
    function orderedBarModules(section_, panel) {
        const ids = root.barModuleIds.filter(function (id) {
            return root.showInBar(id, panel) && root.section(id) === section_
        })
        return root._sortedByOrder(ids)
    }

    // Every bar-shown module regardless of section, in order - used by the
    // "taskbar" bar layout, whose left/center zones are already spoken for
    // by the embedded dock/workspaces (see Bar.qml's own comment), so
    // section assignment is ignored there rather than silently dropping
    // whatever was assigned "left"/"center".
    function orderedBarModulesAnySection(panel) {
        const ids = root.barModuleIds.filter(function (id) { return root.showInBar(id, panel) })
        return root._sortedByOrder(ids)
    }

    // Control Center's reorderable toggle-tile subset (trayModuleIds),
    // tray-shown and enabled, in configured order.
    function orderedTrayModules(panel) {
        const ids = root.trayModuleIds.filter(function (id) { return root.showInTray(id, panel) })
        return root._sortedByOrder(ids)
    }

    // Settings' own Bar Modules tab isn't rendering one specific monitor's
    // bar - it's editing the underlying assignment, so (unlike
    // orderedBarModules above, which Bar.qml itself calls per-panel) this
    // deliberately ignores per-monitor "screens" scoping entirely rather
    // than requiring a real panel object just to satisfy _screenMatches.
    // Every bar-shown, enabled module assigned to `section_` appears here
    // regardless of which monitor(s) it's actually scoped to.
    function barModulesForSettings(section_) {
        const ids = root.barModuleIds.filter(function (id) {
            const e = root._entry(id)
            return e.enabled !== false && !e.tray && root.section(id) === section_
        })
        return root._sortedByOrder(ids)
    }

    // Every enabled module NOT currently shown in any bar section - the
    // Bar Modules tab's own "add a module" dropdown pool (whatever isn't
    // already placed reads as "available to add").
    function barModulesAvailableToAdd() {
        const ids = root.barModuleIds.filter(function (id) {
            const e = root._entry(id)
            return e.enabled === false || !!e.tray
        })
        return ids
    }

    // Control Center tab equivalent - ignores the `panel` param
    // orderedTrayModules needs (showInTray doesn't actually use it, but
    // keeping a distinctly-named function here for symmetry/clarity with
    // barModulesForSettings above, and so a future showInTray change that
    // does start using panel doesn't quietly change Settings' own listing).
    function trayModulesForSettings() {
        const ids = root.trayModuleIds.filter(function (id) { return root._entry(id).enabled !== false && !!root._entry(id).tray })
        return root._sortedByOrder(ids)
    }

    function trayModulesAvailableToAdd() {
        return root.trayModuleIds.filter(function (id) {
            const e = root._entry(id)
            return e.enabled === false || !e.tray
        })
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

    function setSection(id, val) {
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { section: val })
    }

    function setOrder(id, val) {
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { order: val })
    }

    // Drives Settings' Bar Modules drag-and-drop: `orderedIds` is the full,
    // final desired ordering for one bar section (Left/Center/Right),
    // exactly as the UI computed it after a drop - covers both a plain
    // within-section reorder and a cross-section move (the dragged id
    // simply appears in a different section's list) in one call, stamping
    // both `section` and a fresh sequential `order` (0, 1, 2, ...) for
    // every id in the list. The list a moved id's *old* section is left
    // with isn't restamped - safe to leave with a small numeric gap, since
    // order only ever needs to sort correctly among a section's other
    // members, not form a contiguous sequence.
    function reorderBarSection(section_, orderedIds) {
        for (let i = 0; i < orderedIds.length; i++) {
            const id = orderedIds[i]
            const cur = root._entry(id)
            configFile.adapter[id] = Object.assign({}, cur, { section: section_, order: i })
        }
    }

    // Same idea for Control Center's flat (unsectioned) reorderable list.
    function reorderTrayModules(orderedIds) {
        for (let i = 0; i < orderedIds.length; i++) {
            const id = orderedIds[i]
            const cur = root._entry(id)
            configFile.adapter[id] = Object.assign({}, cur, { order: i })
        }
    }

    // "Add a widget" dropdown actions - append the module to the end of
    // its new destination's current order rather than leaving whatever
    // order value it had from the last time it was placed somewhere.
    function addToBarSection(id, section_) {
        const existing = root.barModulesForSettings(section_)
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { enabled: true, tray: false, section: section_, order: existing.length })
    }

    // Just disables the module - doesn't touch tray/section, so it
    // remembers where it was if re-enabled later. Doesn't move it to
    // Control Center either - that's a distinct, explicit action of its
    // own tab's "add" dropdown, not an implicit side effect of removing it
    // from here.
    function removeFromBar(id) {
        root.setEnabled(id, false)
    }

    function addToTray(id) {
        const existing = root.trayModulesForSettings()
        const cur = root._entry(id)
        configFile.adapter[id] = Object.assign({}, cur, { enabled: true, tray: true, order: existing.length })
    }

    function removeFromTray(id) {
        root.setEnabled(id, false)
    }
}
