import QtQuick
import Quickshell
import Quickshell.Io

// Rofi-style application launcher.
//
// Toggle it from anywhere (e.g. a ZarisWM keybind) with:
//   qs ipc call launcher toggle
//
// Usage counts are persisted to Quickshell's reserved state directory and
// used to sort results (most-launched first), so frequently used apps rise
// to the top over time.
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): the plain ListView
// is now NListView (real scrollbar styling + edge-fade gradient masks) and
// the delegate's raw Text is now NText. The search field keeps its own
// bordered-Rectangle+TextInput, same reasoning as every other search/
// filter field in this shell - its Up/Down/Return/Escape key handling
// isn't reachable through NTextInput's inputItem alias from outside the
// component. Both of those live in LauncherContent.qml now (see below).
//
// Two window variants, same "Item root holding shared state, two Window
// children" pattern Dock.qml already uses for its reserved/floating modes:
// a centered FloatingWindow (BarConfig.layoutMode "statusbar", the original
// behavior, positioned via the WM's own title-matched float+center
// windowrule) and a PopupWindow anchored to the bar's own taskbar-mode
// launcher icon (BarConfig.layoutMode "taskbar", LauncherState.anchorItem -
// set by Bar.qml right before toggling visible) - "similarly to Windows UI,
// KDE Plasma, etc." per the user's explicit request for taskbar mode. Only
// one is ever visible at a time; both share the exact same query/
// filteredApps/launch() state (kept here, in the outer Item) and the exact
// same LauncherContent.qml for their actual search+list UI, so switching
// BarConfig.layoutMode doesn't lose or duplicate any of that state.
Item {
    id: root

    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherState.visible = !LauncherState.visible }
        function show(): void { LauncherState.visible = true }
        function hide(): void { LauncherState.visible = false }
    }

    // --- usage tracking ---

    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: usageData
            property var counts: ({})
        }
    }

    function launchCountFor(entryId) {
        return usageData.counts[entryId] || 0
    }

    function recordLaunch(entryId) {
        const updated = Object.assign({}, usageData.counts)
        updated[entryId] = (updated[entryId] || 0) + 1
        usageData.counts = updated
    }

    function launch(app) {
        if (!app)
            return

        recordLaunch(app.id)
        app.execute()
        LauncherState.visible = false
    }

    // --- filtering + usage-based sorting ---

    property string query: ""

    property var filteredApps: {
        const q = query.toLowerCase().trim()
        const all = DesktopEntries.applications.values

        const matches = q === "" ? all : all.filter(function (app) {
            if (app.name && app.name.toLowerCase().includes(q))
                return true
            if (app.comment && app.comment.toLowerCase().includes(q))
                return true
            if (app.keywords && app.keywords.some(function (k) { return k.toLowerCase().includes(q) }))
                return true
            if (app.categories && app.categories.some(function (c) { return c.toLowerCase().includes(q) }))
                return true
            return false
        })

        return matches.slice().sort(function (a, b) {
            const byUsage = launchCountFor(b.id) - launchCountFor(a.id)
            return byUsage !== 0 ? byUsage : a.name.localeCompare(b.name)
        })
    }

    FloatingWindow {
        id: launcherWindow

        visible: LauncherState.visible && BarConfig.layoutMode !== "taskbar"
        title: "Launcher"

        implicitWidth: 600
        implicitHeight: 420

        LauncherContent {
            launcherRoot: root
            active: BarConfig.layoutMode !== "taskbar"
        }
    }

    // Opens downward below the icon when the bar is at the top, upward
    // above it when the bar is at the bottom - mirroring a real taskbar
    // start menu's own behavior either way (Windows/Plasma open upward
    // from a bottom taskbar). Left-aligned under the icon (anchor.rect.x:
    // 0) rather than centered like Settings.qml/CalendarFlyout.qml - a
    // start-menu-style launcher conventionally lines up with its trigger
    // icon's left edge, not straddling it.
    PopupWindow {
        id: launcherPopup

        visible: LauncherState.visible && BarConfig.layoutMode === "taskbar" && !!LauncherState.anchorItem
        color: Colors.bg

        implicitWidth: 420
        implicitHeight: 500

        anchor.item: LauncherState.anchorItem
        anchor.rect.x: 0
        anchor.rect.y: BarConfig.popupAnchorY(LauncherState.anchorItem, implicitHeight)

        LauncherContent {
            launcherRoot: root
            active: BarConfig.layoutMode === "taskbar"
        }
    }
}
