pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bar config, backed by ~/.config/quickshell/bar.json. Same pattern as
// DockConfig.qml/dock.json: hand-editable directly, or through
// Settings.qml - both take effect live, no qs restart needed.
//
//   "layoutMode": "statusbar" | "taskbar"
//                          - "statusbar": Bar.qml looks the way it always
//                            has (logo+workspaces left, clock centered,
//                            status modules + Control Center right) and the
//                            standalone Dock (Dock.qml, its own separate
//                            window(s)) is the only place pinned/running
//                            apps show up, if the user enables it there.
//                          - "taskbar": a Plasma/Windows-style layout -
//                            launcher + an app strip embedded directly in
//                            the bar on the left, workspaces centered, and
//                            status modules + clock + Control Center on the
//                            right (see Bar.qml's own layout comment for the
//                            exact arrangement). The standalone Dock's own
//                            windows are suppressed while this is active -
//                            embedded app icons replace it entirely rather
//                            than the two coexisting.
//   "position": "top" | "bottom"
//                          - which edge of the monitor the bar sits on,
//                            applies in either layoutMode. Deliberately only
//                            these two for now (left/right, like a vertical
//                            dock, is a possible future addition, not done
//                            yet - see ROADMAP.md).
//   "backgroundOpacity": 0.0-1.0 - the bar's background alpha.
//   "height": pixels - the bar's thickness (its PanelWindow's
//                            implicitHeight/exclusiveZone). Clamped to a
//                            sane range so a bad hand-edit can't produce an
//                            unusably thin or huge bar.
//   "launcherIcon": absolute path - the bar's launcher-toggle icon (any
//                            image file, not limited to the bundled
//                            assets). Empty/missing falls back to the
//                            original artix.svg default.
//   "controlCenterIcon": absolute path - the bar's Control Center launcher
//                            icon, same shape as launcherIcon above.
//                            Empty/missing falls back to the original
//                            zaris-logo-square.png default.
QtObject {
    id: root

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/bar.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property string layoutMode: "statusbar"
            property string position: "top"
            property real backgroundOpacity: 0.75
            property int height: 44
            property string launcherIcon: ""
            property string controlCenterIcon: ""
        }
    }

    readonly property string layoutMode: configFile.adapter.layoutMode === "taskbar" ? "taskbar" : "statusbar"
    readonly property string position: configFile.adapter.position === "bottom" ? "bottom" : "top"
    readonly property real backgroundOpacity: {
        const o = configFile.adapter.backgroundOpacity
        return (typeof o === "number" && o >= 0 && o <= 1) ? o : 0.75
    }
    readonly property int height: {
        const h = configFile.adapter.height
        return (typeof h === "number" && h >= 32 && h <= 96) ? Math.round(h) : 44
    }
    readonly property string launcherIcon: configFile.adapter.launcherIcon || (Quickshell.env("HOME") + "/.config/quickshell/assets/artix.svg")
    readonly property string controlCenterIcon: configFile.adapter.controlCenterIcon || (Quickshell.env("HOME") + "/.config/quickshell/assets/zaris-logo-square.png")

    function setLayoutMode(val) {
        configFile.adapter.layoutMode = val
    }

    function setPosition(val) {
        configFile.adapter.position = val
    }

    function setBackgroundOpacity(val) {
        configFile.adapter.backgroundOpacity = val
    }

    function setHeight(val) {
        configFile.adapter.height = Math.round(val)
    }

    function setLauncherIcon(val) {
        configFile.adapter.launcherIcon = val
    }

    function setControlCenterIcon(val) {
        configFile.adapter.controlCenterIcon = val
    }

    // Shared "which way should a bar-anchored popup open" helper - every
    // PopupWindow anchored to something living in the bar (Settings.qml,
    // ControlCenter.qml, CalendarFlyout.qml, Launcher.qml's taskbar-mode
    // variant) needs the exact same direction flip: open downward, below
    // the target, when the bar sits at the top of the screen; open upward,
    // above the target, when it sits at the bottom - otherwise a
    // bottom-positioned bar would push the popup mostly or entirely
    // off-screen instead of staying visually attached to the bar the way
    // the user expects. `targetItem` may be null transiently (before a
    // popup's very first open); callers already guard visibility on it
    // being set, this just avoids a null-dereference in that gap.
    function popupAnchorY(targetItem, popupHeight) {
        if (root.position === "bottom")
            return -popupHeight - 10
        return targetItem ? targetItem.height + 10 : 0
    }
}
