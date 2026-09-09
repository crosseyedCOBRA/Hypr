pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history for X11 - NOT a port of Noctalia's Services/Keyboard/
// ClipboardService.qml, despite fulfilling the same backlog item. Their
// version turned out to be entirely built on Wayland-only external tools
// (cliphist, wl-copy/wl-paste, wtype) - a deeper problem than a QML import
// check catches, since none of that shows up as a `Quickshell.Wayland`
// import, only as shell commands to binaries that simply don't exist/work
// on X11. There's no single obvious drop-in replacement the way `redshift`
// was for NightLightService's `wlsunset` dependency, so this is a genuinely
// new implementation for X11, decided with the user directly: watch the
// real X11 clipboard-change event via `clipnotify` (blocks until the
// CLIPBOARD selection's owner changes, then exits once - relaunched after
// every capture) rather than polling, read new content via `xclip -o`, and
// keep history ourselves rather than depending on a cliphist-equivalent
// history daemon that doesn't exist as a standard X11 tool the way cliphist
// does for Wayland.
//
// `clipnotify` is officially packaged on Arch and Fedora but NOT Debian
// (checked directly against packages.debian.org/sources.debian.org - a
// real gap, not a naming difference, same category as the xautolock/
// betterlockscreen/quickshell/Nerd Font gaps already resolved elsewhere in
// DEPENDENCIES.md). Since it's a tiny, dependency-light C program (X11 +
// Xfixes only), building it from source on Debian is the likely fix,
// mirroring the Quickshell-from-source precedent - not done yet, tracked
// in DEPENDENCIES.md/ROADMAP.md instead of silently assumed away.
//
// The content-type detection (color/link/file/code heuristics below) is
// genuinely portable logic adapted from their version - pure JS pattern
// matching with zero platform coupling, worth keeping even though the
// surrounding mechanism is entirely new.
Singleton {
    id: root

    // Its own small settings file, separate from historyFile below (that
    // one's entries array is write-heavy/local-only, watchChanges: false;
    // this one is a real user setting, watchChanges: true like every other
    // *Config/*Service settings file in this codebase) - added for
    // Settings' new Clipboard tab, previously a hardcoded literal with no
    // way to change it at all.
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/clipboard-settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        adapter: JsonAdapter {
            property int maxEntries: 50
        }
    }

    readonly property int maxEntries: settingsFile.adapter.maxEntries

    function setMaxEntries(val) {
        settingsFile.adapter.maxEntries = val
        if (root.items.length > val) {
            root.items = root.items.slice(0, val)
            root._persist()
        }
    }

    property var items: [] // [{id, content, preview, contentType, timestamp}]
    property bool clipnotifyAvailable: false
    property bool dependencyChecked: false

    Component.onCompleted: {
        dependencyCheckProc.command = ["sh", "-c", "command -v clipnotify"]
        dependencyCheckProc.running = true
    }

    // Checked upfront via `command -v`, the same pattern Noctalia's own
    // original ClipboardService.qml used for `cliphist` - not detected by
    // watching the watcher Process fail, since a `Process` whose command
    // isn't found on PATH never actually fires `exited` at all (that's a
    // QProcess::finished()-only signal under the hood; a genuine failure to
    // start emits a different, internal-only error path this type doesn't
    // expose to QML) - confirmed live: running with clipnotify genuinely
    // uninstalled produced no retry storm, but also never flipped an
    // exited-based availability flag, since that handler simply never ran.
    Process {
        id: dependencyCheckProc
        stdout: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.dependencyChecked = true
            root.clipnotifyAvailable = exitCode === 0
            if (root.clipnotifyAvailable)
                clipnotifyWatcher.running = true
        }
    }

    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.config/quickshell/clipboard-history.json"
        watchChanges: false
        adapter: JsonAdapter {
            id: historyData
            property var entries: []
        }
        Component.onCompleted: {
            if (historyData.entries && historyData.entries.length > 0)
                root.items = historyData.entries
        }
    }

    function _persist() {
        historyData.entries = root.items
        historyFile.writeAdapter()
    }

    // Smart type detection - adapted from Noctalia's ClipboardService.qml,
    // pure pattern-matching logic with no platform coupling at all.
    function contentTypeFor(text) {
        const t = (text || "").trim()
        const tLower = t.toLowerCase()
        if (/^#([a-f0-9]{3}|[a-f0-9]{6}|[a-f0-9]{8})$/.test(tLower))
            return "color"
        if (/^https?:\/\//i.test(t))
            return "link"
        if (/^(\/|~\/|file:\/\/)/i.test(t) && !t.startsWith('//') && !t.includes('\n'))
            return "file"
        if ((t.includes('{') && t.includes('}') && (t.includes(';') || t.includes('='))) ||
            t.includes('</') || t.includes('/>') || t.includes('=>') || t.includes('===') ||
            t.includes('!==') || t.includes('::') || t.includes('->') ||
            /^(?:const|let|var|function|class|struct|interface|type|enum|import|export|func|fn|pub|def|using|namespace|property|public|private|protected)\b/i.test(t) ||
            /^(?:#include|#define|#\[|@|\/\/|\/\*|<\?|<html|<body|<!DOCTYPE)/i.test(t) ||
            /\b(?:require\(|module\.exports)\b/i.test(t))
            return "code"
        return "text"
    }

    function _makePreview(text) {
        const oneLine = text.replace(/\s+/g, " ").trim()
        return oneLine.length > 100 ? oneLine.slice(0, 100) + "…" : oneLine
    }

    // Only ever started after dependencyCheckProc confirms clipnotify
    // actually exists - see the comment above on why that check has to
    // happen upfront rather than by watching this Process fail.
    Process {
        id: clipnotifyWatcher
        command: ["clipnotify", "-s", "clipboard"]
        running: false
        onExited: (exitCode, exitStatus) => {
            root._captureClipboard()
            clipnotifyWatcher.running = true
        }
    }

    Process {
        id: captureProc
        command: ["xclip", "-selection", "clipboard", "-o"]
        stdout: StdioCollector {
            onStreamFinished: root._onCaptured(this.text)
        }
    }

    function _captureClipboard() {
        captureProc.running = true
    }

    function _onCaptured(text) {
        if (!text || text.trim() === "")
            return
        // Skip if identical to the most recent entry (clipnotify can fire
        // more than once for the same content, e.g. a selection re-owned
        // by the same app without new content).
        if (root.items.length > 0 && root.items[0].content === text)
            return

        const entry = {
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 10000),
            content: text,
            preview: root._makePreview(text),
            contentType: root.contentTypeFor(text),
            timestamp: Date.now()
        }

        const updated = [entry].concat(root.items)
        root.items = updated.length > root.maxEntries ? updated.slice(0, root.maxEntries) : updated
        root._persist()
    }

    Process {
        id: copyProc
        stdout: StdioCollector {}
    }

    // Passes content through a shell-escaped `printf` argument rather than
    // a temp file or Quickshell Process's own stdin-write API - the latter
    // has no documented way to signal EOF to the child process (xclip needs
    // to see end-of-input before it forks into the background holding the
    // selection), which a shell-escaped command-line argument sidesteps
    // entirely. Same escaping approach Noctalia's own ClipboardService.qml
    // used for its equivalent `pasteText()` (replace each literal single
    // quote with close-quote + escaped-quote + reopen-quote) - proven
    // pattern, not invented fresh here.
    function copyToClipboard(id) {
        const item = root.items.find(function (i) { return i.id === id })
        if (!item)
            return
        const escaped = item.content.replace(/'/g, "'\\''")
        copyProc.command = ["sh", "-c", "printf '%s' '" + escaped + "' | xclip -selection clipboard"]
        copyProc.running = true
    }

    function deleteById(id) {
        root.items = root.items.filter(function (i) { return i.id !== id })
        root._persist()
    }

    function wipeAll() {
        root.items = []
        root._persist()
    }
}
