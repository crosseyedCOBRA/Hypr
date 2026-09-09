pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Directory-navigation picker for folder-valued settings (currently just
// Defaults' "Screenshot folder") - a genuinely different UX from
// IconPickerPanel.qml/WallpaperPickerPanel.qml's flat thumbnail grids,
// since picking a FOLDER means navigating into/out of directories rather
// than selecting one file out of a flat list. `onSelect` is a plain JS
// callback set by whichever field opened the picker, called with the
// chosen absolute path on confirm - a callback rather than a fixed target
// enum (IconPickerPanelState's own "launcher"/"controlCenter" pattern)
// since a folder-valued setting could reasonably live anywhere in
// Settings, not just one or two known fields.
QtObject {
    id: root

    property bool visible: false
    property string directory: Quickshell.env("HOME")
    property var subdirs: [] // subdirectory names only, sorted
    property bool scanning: false
    property var onSelect: null

    function open(startDirectory, callback) {
        root.onSelect = callback
        root.directory = (startDirectory && startDirectory !== "") ? startDirectory : Quickshell.env("HOME")
        root.visible = true
        root.scan()
    }

    function scan() {
        if (root.scanning)
            return
        root.scanning = true
        // Plain argv array, not a `sh -c` string - nothing to escape
        // regardless of what characters the directory path contains, same
        // reasoning IconPickerPanelState.qml/WallpaperService.qml's own
        // scan()s already established.
        scanProc.command = ["find", root.directory, "-maxdepth", "1", "-mindepth", "1", "-type", "d"]
        scanProc.running = true
    }

    function navigateInto(name) {
        root.directory = root.directory.replace(/\/$/, "") + "/" + name
        root.scan()
    }

    function navigateUp() {
        if (root.directory === "/")
            return
        const trimmed = root.directory.replace(/\/$/, "")
        const idx = trimmed.lastIndexOf("/")
        root.directory = idx <= 0 ? "/" : trimmed.slice(0, idx)
        root.scan()
    }

    function selectCurrent() {
        if (root.onSelect)
            root.onSelect(root.directory)
        root.visible = false
    }

    property Process scanProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = this.text.split("\n").filter(function (l) { return l.length > 0 })
                root.subdirs = paths.map(function (p) { return p.slice(p.lastIndexOf("/") + 1) }).sort()
                root.scanning = false
            }
        }
    }
}
