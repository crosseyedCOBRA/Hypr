pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared pinned+running app list, extracted out of Dock.qml so both the
// standalone dock (Dock.qml, DockConfig.mode "reserved"/"floating") and the
// bar's embedded taskbar-mode app strip (Bar.qml, BarConfig.layoutMode
// "taskbar") can use the exact same data and the exact same wmctrl poll,
// rather than each running its own separate one. Only one of those two UIs
// is ever actually shown at a time in practice (Dock.qml suppresses its own
// windows while BarConfig.layoutMode is "taskbar" - see Dock.qml's own
// comment) but the polling itself stays independent of which UI (if any)
// is currently displaying it.
//
// Running-window tracking uses `wmctrl -lx` polled on a timer, same
// approach as Workspaces.qml, for the same reason: there's no generic X11
// EWMH window-list service in Quickshell, only its native Hyprland/i3
// integrations. Matching a running window to an installed .desktop entry is
// a best-effort heuristic (WM_CLASS vs desktop-entry id/name, case
// insensitive) since nothing here reads `StartupWMClass` -- good enough for
// the common case, not guaranteed for every app.
QtObject {
    id: root

    property var runningWindows: [] // [{id, wmClass, title}]

    function classMatches(wmClass, entry) {
        if (!wmClass || !entry)
            return false

        const wmClassLower = wmClass.toLowerCase()

        // Primary signal: the desktop entry's own StartupWMClass (Quickshell:
        // entry.startupClass), the freedesktop-standard field that exists
        // specifically for apps whose window class has nothing in common
        // with their id/name - exactly the case for WebApp Hub-generated
        // entries, whose id is an opaque generated string (e.g.
        // "org.chromium.Chromium.chromium-wah-N49CAAJH") while their real
        // WM_CLASS is domain-derived (e.g.
        // "music.youtube.com.chrome-music.youtube.com__-Default", which does
        // contain the app's declared StartupWMClass,
        // "chrome-music.youtube.com__-Default", as a substring - a full
        // string containment check here, not the fragment-based one below,
        // since StartupWMClass values are themselves often dot-containing
        // and a per-app-declared value carries no false-positive risk the
        // way matching on a generic split fragment would).
        const startupClass = (entry.startupClass || "").toLowerCase()
        if (startupClass.length > 0 && wmClassLower.indexOf(startupClass) !== -1)
            return true

        // Fallback: exact-token comparison only - no generic substring
        // matching. A dot-heavy WM_CLASS splits into short, generic
        // fragments ("com", "youtube") that a substring check would
        // false-positive-match against an unrelated entry whose id merely
        // contains the same fragment (confirmed live: "com" matched
        // "com.chatterino.chatterino", showing that icon for the YouTube
        // Music window instead, before this entry had a StartupWMClass check
        // to catch it above). Exact equality against the whole id, the id's
        // last dot-segment (reverse-DNS ids like "app.zen_browser.zen"
        // commonly share just that last piece with WM_CLASS), or the name is
        // far more conservative - worst case is a missed match (generic
        // fallback icon), never a wrong one.
        const parts = wmClassLower.split(".").filter(function (p) { return p.length > 0 })
        const id = (entry.id || "").toLowerCase()
        const idLastSegment = id.split(".").pop()
        const name = (entry.name || "").toLowerCase().replace(/\s+/g, "")
        return parts.some(function (p) {
            return p === id || p === idLastSegment || p === name
        })
    }

    // Flattened list DockIcons.qml renders: pinned apps first (in configured
    // order), then any running app that isn't already covered by a pinned
    // one, appended after.
    property var dockItems: {
        const apps = DesktopEntries.applications.values
        const items = []
        const coveredClasses = {}

        DockConfig.pinned.forEach(function (id) {
            const entry = apps.find(function (a) { return a.id === id })
            if (!entry)
                return
            const wins = root.runningWindows.filter(function (w) { return root.classMatches(w.wmClass, entry) })
            wins.forEach(function (w) { coveredClasses[w.wmClass] = true })
            items.push({
                id: entry.id,
                name: entry.name,
                icon: entry.icon || "",
                pinned: true,
                running: wins.length > 0,
                windowIds: wins.map(function (w) { return w.id }),
                entry: entry
            })
        })

        const seenClasses = {}
        root.runningWindows.forEach(function (w) {
            if (coveredClasses[w.wmClass] || seenClasses[w.wmClass])
                return
            seenClasses[w.wmClass] = true

            const matchedEntry = apps.find(function (a) { return root.classMatches(w.wmClass, a) })
            const wins = root.runningWindows.filter(function (w2) { return w2.wmClass === w.wmClass })
            items.push({
                id: matchedEntry ? matchedEntry.id : null,
                name: matchedEntry ? matchedEntry.name : w.wmClass.split(".").pop(),
                icon: matchedEntry ? (matchedEntry.icon || "") : "",
                pinned: false,
                running: true,
                windowIds: wins.map(function (w2) { return w2.id }),
                entry: matchedEntry || null
            })
        })

        return items
    }

    function activate(windowId) {
        activator.command = ["wmctrl", "-ia", windowId]
        activator.running = true
    }

    property Process activator: Process { id: activator }

    property Process lister: Process {
        id: lister
        command: ["wmctrl", "-lx"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(function (l) { return l.length > 0 })
                root.runningWindows = lines.map(function (line) {
                    const m = line.match(/^(\S+)\s+(-?\d+)\s+(\S+)\s+(\S+)\s+(.*)$/)
                    return m ? {id: m[1], wmClass: m[3], title: m[5]} : null
                }).filter(function (w) { return w !== null })
            }
        }
    }

    // Polls whenever either UI that could actually show this data is
    // active - the standalone dock, or the bar's embedded taskbar-mode
    // strip - so switching between them (or enabling/disabling the
    // standalone dock) doesn't need anything here to change.
    property Timer poller: Timer {
        interval: 1000
        running: DockConfig.enabled || BarConfig.layoutMode === "taskbar"
        repeat: true
        triggeredOnStart: true
        onTriggered: lister.running = true
    }
}
