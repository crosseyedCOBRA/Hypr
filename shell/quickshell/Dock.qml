import QtQuick
import Quickshell
import Quickshell.Io

// App dock: a static launcher icon (DockLauncherIcon.qml) plus pinned apps
// (right-click "Pin to Dock" on a Launcher result) and currently-running
// apps (DockIcons.qml), one icon per app either way - which end of the dock
// the launcher sits at, and whether the dock lays icons out in a row or a
// column, both come from DockConfig (position/launcherPosition), see
// DockContent.qml.
//
// Which monitor(s) show a dock at all is now DockConfig.screens-driven
// (same "all"/"primary"/[exact output names] shape as ModulesConfig.qml's
// per-module screens field) via a per-monitor Variants wrapper, same
// dedup-mirrored-outputs pattern as Bar.qml - a dock duplicated across two
// XRandR outputs that are actually the same mirrored physical display would
// otherwise create a second, fully overlapping window. Previously always
// exactly one dock, hardcoded to the primary monitor.
//
// Running-window tracking uses `wmctrl -lx` polled on a timer, same
// approach as Workspaces.qml, for the same reason: there's no generic X11
// EWMH window-list service in Quickshell, only its native Hyprland/i3
// integrations. Matching a running window to an installed .desktop entry is
// a best-effort heuristic (WM_CLASS vs desktop-entry id/name, case
// insensitive) since nothing here reads `StartupWMClass` -- good enough for
// the common case, not guaranteed for every app. Deliberately kept as
// shared, monitor-independent state (not duplicated per Variants instance)
// - the running-app list and its wmctrl polling are the same regardless of
// which/how-many monitors a dock is actually shown on.
//
// Two window variants share the same DockContent; only the one matching
// DockConfig.mode is ever visible for a given monitor. They can't be one
// adaptable window since Quickshell's PanelWindow (reserves screen space,
// exactly like Bar.qml) and FloatingWindow (positioned via the WM's own
// `*center` windowrules, matched against this window's own dynamic title -
// see the FloatingWindow's own comment below for why - reserves nothing)
// are fundamentally different window types.
Item {
    id: root

    readonly property color dockBg: {
        const c = Qt.color(DockConfig.backgroundColor)
        return Qt.rgba(c.r, c.g, c.b, DockConfig.backgroundOpacity)
    }

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

    Process { id: activator }

    Process {
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

    Timer {
        interval: 1000
        running: DockConfig.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: lister.running = true
    }

    Variants {
        model: {
            const seen = []
            const result = []
            for (const s of Quickshell.screens) {
                if (!DockConfig.screenMatches(s))
                    continue
                const key = s.x + "," + s.y + "," + s.width + "," + s.height
                if (seen.includes(key))
                    continue
                seen.push(key)
                result.push(s)
            }
            return result
        }

        // Variants only accepts a single delegate, so both window variants
        // live inside one wrapping Item rather than as two direct children
        // - Window-type objects don't need a visual QQuickItem parent to
        // render correctly, this is purely to satisfy that one-delegate
        // constraint.
        Item {
            id: dockDelegate
            required property var modelData

            // Auto-hide (DockConfig.autoHide, floating mode only - reserved
            // is always fully visible, same as the bar) works by swapping
            // between two separate windows sharing the exact same
            // title-matched positioning (both set title: "Dock-" +
            // DockConfig.position, so the WM's existing *center windowrule
            // family positions either one identically, no new WM-side rule
            // needed) rather than the dock itself shrinking to a hint strip
            // and growing back - deliberately, since Dock.qml's own
            // Loader-recreation comment below already established that
            // FloatingWindow doesn't reliably resize/reposition after
            // first map, so an animated grow/shrink of the SAME window
            // on hover wouldn't be reliable either. A small always-present
            // trigger window (hoverRevealed false) swaps for the real,
            // full dock (hoverRevealed true) the instant the pointer
            // enters it - each swap is a fresh Loader-driven creation, not
            // a resize, so it's exactly as reliable as the position-change
            // handling already is.
            property bool hoverRevealed: false
            readonly property bool revealed: !DockConfig.autoHide || dockDelegate.hoverRevealed

            function reveal() {
                hideTimer.stop()
                dockDelegate.hoverRevealed = true
            }

            function scheduleHide() {
                if (DockConfig.autoHide)
                    hideTimer.restart()
            }

            Timer {
                id: hideTimer
                interval: 600
                onTriggered: dockDelegate.hoverRevealed = false
            }

            PanelWindow {
                id: reservedDock

                // No anchors on the non-anchored axis, unlike Bar.qml - a
                // dock should hug its content and stay centered along that
                // axis even while reserving space, not span the full
                // screen edge to edge like the bar does. Anchoring only
                // one edge (whichever DockConfig.position says) centers
                // along the other, same as Bar.qml's underlying panel
                // semantics.
                visible: DockConfig.enabled && DockConfig.mode === "reserved"
                screen: dockDelegate.modelData

                anchors.top: DockConfig.position === "top"
                anchors.bottom: DockConfig.position === "bottom"
                anchors.left: DockConfig.position === "left"
                anchors.right: DockConfig.position === "right"

                implicitWidth: DockConfig.isVertical ? 56 : Math.max(reservedContent.implicitWidth + 24, 60)
                implicitHeight: DockConfig.isVertical ? Math.max(reservedContent.implicitHeight + 24, 60) : 56
                exclusiveZone: 56
                color: "transparent"

                // No margin/radius here - the WM now shape-masks dock-type
                // windows for real rounding (see applyShapeToWindow in
                // windowManager.cpp), so this just needs to fill the
                // window's actual shape edge to edge rather than
                // approximate rounding with its own inset+radius, which
                // (with no compositor to blend alpha) rendered as an
                // opaque black square peeking out around the edges instead
                // of true transparency.
                Rectangle {
                    anchors.fill: parent
                    color: root.dockBg
                }

                DockContent {
                    id: reservedContent
                    anchors.centerIn: parent
                    model: root.dockItems
                    onActivateRequested: root.activate(windowId)
                    onLaunchRequested: entry.execute()
                    onReorderRequested: DockConfig.reorderPinned(appId, newIndex)
                }
            }

            // FloatingWindow, not a Loader-recreated one - a real,
            // separately-confirmed regression found while testing this
            // exact auto-hide feature: a Loader that destroys and
            // recreates a FloatingWindow (which the position-change
            // handling below used to do, to force a fresh size
            // negotiation) can come back tiled instead of floated, at
            // whatever size the tiling layout gives it - confirmed
            // reproducing on a clean, single-property-unchanged launch,
            // not a timing race from rapid edits. Root cause: the WM's
            // `float`/`*center` windowrules match by title at the exact
            // moment a window is first mapped, and a Loader-instantiated
            // window's `title` binding doesn't reliably finish applying
            // before that first map the way a directly-declared window's
            // does - so the rule can miss entirely and the window falls
            // through to ordinary tiling. Reverted to a plain,
            // always-instantiated FloatingWindow (the same "always exists,
            // visible toggles" pattern already used everywhere else in
            // this codebase - Settings.qml, ControlCenter.qml, etc.).
            //
            // Known, accepted limitation from this revert: a `visible`
            // false-then-true toggle (below) forces a real unmap/remap,
            // which does correctly reposition on a live DockConfig.position
            // change (the WM computes position fresh from the monitor
            // geometry every time) - but NOT reliably resize for an
            // orientation change (top/bottom <-> left/right), since
            // resizing depends on the *real* X11 window already being the
            // right size when the WM re-reads its geometry on remap, and
            // Quickshell doesn't reliably push a FloatingWindow's
            // implicitWidth/implicitHeight changes to the actual platform
            // window after its first-ever map (the same limitation
            // ControlCenter.qml's own header comment documents, worked
            // around there with a fixed size - not viable here since
            // top/bottom and left/right genuinely need different aspect
            // ratios). A live orientation change while already floating
            // will reposition correctly but may need a full `qs` restart
            // to resize correctly - reserved mode (a PanelWindow, not
            // subject to this at all) is unaffected and handles every
            // orientation change live with no such caveat.
            FloatingWindow {
                id: floatingDock

                readonly property bool shouldBeVisible: DockConfig.enabled && DockConfig.mode === "floating" && dockDelegate.revealed
                visible: floatingDock.shouldBeVisible
                screen: dockDelegate.modelData

                // The WM has no way to read DockConfig.json itself -
                // floating positioning is entirely driven by title-matched
                // windowrules (see zaris.conf's
                // `windowrule=*center ...,title:^Dock-...$` lines), the
                // same mechanism the launcher/Settings/etc. already use.
                title: "Dock-" + DockConfig.position

                // Forces the remap described above so a live position
                // change actually repositions rather than silently doing
                // nothing until some other event happens to remap this
                // window. Property change handlers don't fire for a
                // binding's initial evaluation, only real subsequent
                // changes, so this doesn't cause a startup flicker.
                onTitleChanged: {
                    floatingDock.visible = false
                    floatingRemapTimer.start()
                }

                Timer {
                    id: floatingRemapTimer
                    interval: 1
                    onTriggered: floatingDock.visible = Qt.binding(function () { return floatingDock.shouldBeVisible })
                }

                implicitWidth: DockConfig.isVertical ? 56 : Math.max(floatingContent.implicitWidth + 24, 60)
                implicitHeight: DockConfig.isVertical ? Math.max(floatingContent.implicitHeight + 24, 60) : 56

                // Same reasoning as the reserved-mode Rectangle above -
                // no radius, the WM's shape mask handles rounding now.
                Rectangle {
                    anchors.fill: parent
                    color: root.dockBg
                }

                // Hover tracking for auto-hide only - a no-op when
                // DockConfig.autoHide is false, since scheduleHide()
                // itself checks that. HoverHandler rather than a MouseArea
                // - a real bug caught by testing, not assumed: a
                // z: -1 MouseArea here never saw hover at all while the
                // pointer was directly over an icon, since each icon's own
                // (higher, default-z) MouseArea wins Qt's normal
                // one-MouseArea-at-a-time hover exclusivity, so leaving
                // the dock FROM an icon never fired this one's onExited
                // and the dock never re-hid. HoverHandler is a separate
                // input-handler mechanism that observes hover state
                // without competing with MouseAreas for it, so it
                // correctly tracks "is the pointer anywhere over this
                // window" regardless of what's on top at that exact point.
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            hideTimer.stop()
                        else
                            dockDelegate.scheduleHide()
                    }
                }

                DockContent {
                    id: floatingContent
                    anchors.centerIn: parent
                    model: root.dockItems
                    onActivateRequested: root.activate(windowId)
                    onLaunchRequested: entry.execute()
                    onReorderRequested: DockConfig.reorderPinned(appId, newIndex)
                }
            }

            // The auto-hide trigger strip - see dockDelegate's own comment
            // above for why this exists. Same always-instantiated,
            // visible-toggling pattern as the real dock above, for the
            // exact same reason (avoiding the Loader-recreation bug).
            // Fixed, modest dimensions (not sized to the real dock's
            // actual content width) - it's just a hint the dock exists
            // here, not a preview of it.
            FloatingWindow {
                id: triggerDock

                readonly property bool shouldBeVisible: DockConfig.enabled && DockConfig.mode === "floating" && DockConfig.autoHide && !dockDelegate.revealed
                visible: triggerDock.shouldBeVisible
                screen: dockDelegate.modelData
                title: "Dock-" + DockConfig.position

                onTitleChanged: {
                    triggerDock.visible = false
                    triggerRemapTimer.start()
                }

                Timer {
                    id: triggerRemapTimer
                    interval: 1
                    onTriggered: triggerDock.visible = Qt.binding(function () { return triggerDock.shouldBeVisible })
                }

                implicitWidth: DockConfig.isVertical ? 6 : 80
                implicitHeight: DockConfig.isVertical ? 80 : 6

                Rectangle {
                    anchors.fill: parent
                    color: Colors.pillActive
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: dockDelegate.reveal()
                }
            }
        }
    }
}
