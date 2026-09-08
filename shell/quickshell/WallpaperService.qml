pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper picker/rotation - NOT a port of Noctalia's Services/UI/
// WallpaperService.qml, despite fulfilling the same backlog item. That
// file (1683 lines) turned out to be deeply entangled with their dynamic
// per-wallpaper color-scheme extraction and light/dark "appearance slot"
// system - the same dynamic wallpaper-based color generation already
// deferred as its own separate decision elsewhere in this file's history
// (see the Material color-role entry above). Porting it properly would
// mean building that system first. The actual backlog item just asks for
// "a wallpaper picker/rotation" instead of the single static `xwallpaper`
// call already in `zaris.conf` - a much smaller, genuinely new
// implementation scoped to that, non-recursive directory scan, no
// favorites/theme-extraction/per-monitor appearance slots.
Singleton {
    id: root

    readonly property string defaultDirectory: Quickshell.env("HOME") + "/Pictures"

    property var images: [] // absolute file paths
    property bool scanning: false

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property string directory: root.defaultDirectory
            property string current: ""
            property bool rotationEnabled: false
            property int rotationIntervalMinutes: 30
        }
    }

    readonly property string directory: configFile.adapter.directory
    readonly property string current: configFile.adapter.current
    readonly property bool rotationEnabled: configFile.adapter.rotationEnabled
    readonly property int rotationIntervalMinutes: configFile.adapter.rotationIntervalMinutes

    function setDirectory(path) {
        configFile.adapter.directory = path
        scan()
    }

    function setRotationEnabled(val) {
        configFile.adapter.rotationEnabled = val
    }

    function setRotationInterval(minutes) {
        configFile.adapter.rotationIntervalMinutes = minutes
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.images = this.text.split("\n").filter(function (l) { return l.length > 0 }).sort()
                root.scanning = false
            }
        }
    }

    function scan() {
        if (scanning)
            return
        scanning = true
        // Passed as a plain argv array, not a `sh -c` string - each element
        // reaches `find` literally with no shell involved, so there's
        // nothing to escape regardless of what characters the configured
        // directory path happens to contain.
        scanProc.command = ["find", root.directory, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        scanProc.running = true
    }

    Process {
        id: setProc
    }

    function setWallpaper(path) {
        if (!path)
            return
        setProc.command = ["xwallpaper", "--zoom", path]
        setProc.running = true
        configFile.adapter.current = path
    }

    function setRandomWallpaper() {
        if (root.images.length === 0)
            return
        const others = root.images.filter(function (p) { return p !== root.current })
        const pool = others.length > 0 ? others : root.images
        setWallpaper(pool[Math.floor(Math.random() * pool.length)])
    }

    Timer {
        interval: root.rotationIntervalMinutes * 60 * 1000
        running: root.rotationEnabled && root.images.length > 1
        repeat: true
        onTriggered: root.setRandomWallpaper()
    }

    Component.onCompleted: scan()
}
