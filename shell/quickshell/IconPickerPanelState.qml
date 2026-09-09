pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared state for IconPickerPanel.qml, same pattern as
// WallpaperPickerPanelState.qml/BluetoothPanelState.qml. Built to replace
// the Bar tab's Launcher/Control Center icon "Browse" buttons -
// QtQuick.Dialogs' FileDialog was tried first (a real, standard Qt type)
// and confirmed to render/open correctly, but was completely unclickable
// once a real WM is running (see ROADMAP.md's own investigation writeup
// for the full root-cause dig, never resolved). This sidesteps that bug
// entirely with a custom in-QML picker instead, the same "GridView-based
// picker, not a native dialog" approach WallpaperPickerPanel.qml already
// proved out - genuinely working today rather than blocked on a WM fix.
//
// `target` says which BarConfig setter a click should call
// ("launcher"/"controlCenter") - one shared picker instance for both
// fields rather than two near-identical panels, set right before opening
// by whichever field's own Browse button was clicked.
//
// Its own scan/directory state (rather than reusing WallpaperService.qml)
// since this is a genuinely different concern - icon files, not
// wallpapers, defaulting to the shell's own bundled assets folder instead
// of ~/Pictures, and with no rotation concept at all.
QtObject {
    id: root

    property bool visible: false
    property string target: "launcher" // "launcher" or "controlCenter"

    readonly property string defaultDirectory: Quickshell.env("HOME") + "/.config/quickshell/assets"
    property string directory: root.defaultDirectory

    property var images: [] // absolute file paths
    property bool scanning: false

    function open(forTarget) {
        root.target = forTarget
        root.visible = true
        root.scan()
    }

    function scan() {
        if (root.scanning)
            return
        root.scanning = true
        // Plain argv array, not a `sh -c` string - see
        // WallpaperService.qml's identical scan() for why (nothing to
        // escape regardless of what characters the directory path
        // contains). svg included alongside the usual raster formats -
        // BarConfig's own default launcher icon is an .svg.
        scanProc.command = ["find", root.directory, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.svg", "-o", "-iname", "*.png", "-o", "-iname", "*.jpg",
            "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", ")"]
        scanProc.running = true
    }

    property Process scanProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = this.text.split("\n").filter(function (l) { return l.length > 0 }).sort()
                root.scanning = false
            }
        }
    }

    function select(path) {
        if (root.target === "controlCenter")
            BarConfig.setControlCenterIcon(path)
        else
            BarConfig.setLauncherIcon(path)
        root.visible = false
    }
}
