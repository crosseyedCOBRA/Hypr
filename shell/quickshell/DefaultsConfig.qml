pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System-wide defaults a user would reasonably expect to configure once and
// have apply everywhere - icon theme, shell font family/size, and the
// default web browser. Backed by ~/.config/quickshell/defaults.json for
// Zaris's own remembered choice (same FileView+JsonAdapter pattern as every
// other *Config.qml), but unlike those, most of these settings also reach
// *outside* Quickshell entirely:
//
//   - Icon theme: written into both ~/.config/qt6ct/qt6ct.conf's
//     `icon_theme=` (this shell is a Qt app, launched with
//     QT_QPA_PLATFORMTHEME=qt6ct already, so this is genuinely what Qt/
//     Quickshell resolves DesktopEntries/Quickshell.iconPath() icons
//     against) and ~/.config/gtk-3.0/gtk-4.0's `gtk-icon-theme-name=` (so
//     GTK apps stay visually consistent with the same choice) - a plain
//     `key=value` line replace in each already-existing config file via
//     FileView.text()/setText(), the same mechanism ThemeConfig.qml
//     already uses for zaris.conf's border color. Confirmed live as the
//     actual root cause of Dock/Launcher icons not matching the rest of
//     the desktop's icon theme: qt6ct's own icon_theme was simply blank,
//     so Qt/Quickshell had no real theme to resolve icons against at all,
//     while GTK apps were already using Papirus-Dark.
//   - Cursor theme/size: written into THREE places, since this reference
//     machine turned out to already have all three wired up and pointing
//     at the same values (checked live with `xrdb -query` before assuming
//     anything): ~/.icons/default/index.theme's `Inherits=` line, both
//     GTK settings.ini's `gtk-cursor-theme-name=`/`gtk-cursor-theme-size=`,
//     and - confirmed the most authoritative one, since libXcursor checks
//     it before falling back to index.theme - ~/.Xresources's own
//     `Xcursor.theme:`/`Xcursor.size:` lines (note the colon-space
//     separator, not `=` - a genuinely different text format from every
//     other file this singleton touches, handled by its own
//     _setXresourceKey rather than reusing _setIniKey). Xresources changes
//     are re-merged into the live X server via `xrdb -merge` right after
//     writing, which is real and immediate at the X resource database
//     level - but this WM's own root cursor
//     (CWindowManager::updateRootCursor(), windowManager.cpp) and any
//     already-running GTK/Qt app still only resolve cursors at their own
//     startup, so the same "needs an actual restart to see it" caveat as
//     everything else here still applies to what's already on screen.
//   - Font family: applied to this shell's own text (Style.qml/NText.qml)
//     directly, and also written to gtk-font-name in both gtk-3.0 and
//     gtk-4.0 settings.ini so GTK apps match. Deliberately NOT written to
//     qt6ct's own font setting - Qt stores it as a fully serialized QFont
//     string (family, pixel size, weight, style, stretch, and more, all
//     comma-packed) with no simple text format to safely hand-construct,
//     unlike every other value this file touches. Other native Qt apps on
//     the system keep their own font as a result - a real, accepted gap,
//     not something worth risking a malformed qt6ct.conf over.
//   - Font size: a single base size (default 11, matching this shell's own
//     previous hardcoded Style.fontSizeM and GTK's own current default)
//     that scales every one of Style.qml's font size tokens proportionally
//     via fontScale, rather than exposing each token individually.
//   - Default browser: applied via `xdg-settings set default-web-browser`,
//     the standard XDG mechanism every proper desktop uses - not a
//     Zaris-specific config file at all.
//
// Both qt6ct and GTK settings are read once at each app's own startup, not
// hot-reloaded the way Quickshell's own JSON configs are - changing one of
// these needs a real process restart (this shell killed and relaunched, or
// a GTK app restarted) to actually take visual effect. Settings' "Reload
// Shell UI" button (restartShell() below) does NOT cover this - confirmed
// live that it only reloads Quickshell's own QML tree in place (same OS
// process, verified via the process id never changing), which never
// touches Qt's own icon theme at all since that's resolved once at
// QGuiApplication construction, not on any later reload.
QtObject {
    id: root

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/defaults.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property string iconTheme: ""
            property string cursorTheme: ""
            property real cursorSize: 24
            property string fontFamily: ""
            property real fontSize: 11
            property string defaultBrowser: ""
        }
    }

    readonly property string iconTheme: configFile.adapter.iconTheme
    readonly property string cursorTheme: configFile.adapter.cursorTheme
    readonly property real cursorSize: {
        const s = configFile.adapter.cursorSize
        return (typeof s === "number" && s >= 16 && s <= 64) ? s : 24
    }
    readonly property string fontFamily: configFile.adapter.fontFamily || Qt.application.font.family
    readonly property real fontSize: {
        const s = configFile.adapter.fontSize
        return (typeof s === "number" && s >= 8 && s <= 20) ? s : 11
    }
    // Every Style.qml font size token is multiplied by this - 11 is the
    // baseline (today's shipped Style.fontSizeM), so leaving fontSize at
    // its default keeps fontScale at exactly 1 (no change at all).
    readonly property real fontScale: root.fontSize / 11
    readonly property string defaultBrowser: configFile.adapter.defaultBrowser

    // --- icon theme: enumerate installed themes, then apply ---

    property var availableIconThemes: []

    property Process iconThemeScanner: Process {
        // Excludes cursor themes (Bibata etc. - real icon themes always
        // declare Directories=, a cursor-only theme's index.theme doesn't)
        // and Hidden=true entries (hicolor, the spec's own fallback-only
        // theme - not meant to be picked directly, same convention every
        // other icon theme picker follows).
        command: ["sh", "-c", "for d in /usr/share/icons/*/ ~/.local/share/icons/*/ ~/.icons/*/; do f=\"$d/index.theme\"; [ -f \"$f\" ] || continue; grep -qi '^Hidden=true' \"$f\" && continue; grep -q '^Directories=' \"$f\" || continue; n=$(grep '^Name=' \"$f\" | head -1 | cut -d= -f2-); b=$(basename \"$d\"); echo \"$b|${n:-$b}\"; done | sort -u -t'|' -k1,1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(function (l) { return l.length > 0 })
                root.availableIconThemes = lines.map(function (l) {
                    const parts = l.split("|")
                    return { key: parts[0], name: parts[1] || parts[0] }
                })
            }
        }
    }

    // --- cursor theme: enumerate installed themes, then apply ---

    property var availableCursorThemes: []

    property Process cursorThemeScanner: Process {
        // A real cursor theme always ships a cursors/ subdirectory of
        // actual cursor files - unlike icon themes (Directories=), that's
        // the one reliable signal here, since a theme can ship icons,
        // cursors, both, or (Bibata) cursors only, and index.theme's own
        // fields don't reliably distinguish which.
        command: ["sh", "-c", "for d in /usr/share/icons/*/ ~/.local/share/icons/*/ ~/.icons/*/; do [ -d \"$d/cursors\" ] || continue; f=\"$d/index.theme\"; n=$(grep '^Name=' \"$f\" 2>/dev/null | head -1 | cut -d= -f2-); b=$(basename \"$d\"); echo \"$b|${n:-$b}\"; done | sort -u -t'|' -k1,1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(function (l) { return l.length > 0 })
                root.availableCursorThemes = lines.map(function (l) {
                    const parts = l.split("|")
                    return { key: parts[0], name: parts[1] || parts[0] }
                })
            }
        }
    }

    // --- font family: enumerate installed families ---

    property var availableFonts: []

    property Process fontScanner: Process {
        command: ["sh", "-c", "fc-list : family | sed 's/,.*//' | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(function (l) { return l.length > 0 })
                root.availableFonts = lines.map(function (l) { return { key: l, name: l } })
            }
        }
    }

    // --- default browser: reuse DesktopEntries, already available to the
    // launcher, rather than a separate scan ---

    readonly property var availableBrowsers: {
        const apps = DesktopEntries.applications.values
        return apps.filter(function (a) {
            return a.categories && a.categories.indexOf("WebBrowser") !== -1
        }).map(function (a) {
            return { key: a.id, name: a.name }
        })
    }

    Component.onCompleted: {
        iconThemeScanner.running = true
        cursorThemeScanner.running = true
        fontScanner.running = true
    }

    // --- qt6ct.conf / gtk settings.ini / cursor index.theme text-mode FileViews ---

    property FileView qt6ctFile: FileView {
        path: Quickshell.env("HOME") + "/.config/qt6ct/qt6ct.conf"
        watchChanges: true
        onFileChanged: reload()
    }

    property FileView cursorIndexFile: FileView {
        path: Quickshell.env("HOME") + "/.icons/default/index.theme"
        watchChanges: true
        onFileChanged: reload()
    }

    property FileView xresourcesFile: FileView {
        path: Quickshell.env("HOME") + "/.Xresources"
        watchChanges: true
        onFileChanged: reload()
    }

    property FileView gtk3File: FileView {
        path: Quickshell.env("HOME") + "/.config/gtk-3.0/settings.ini"
        watchChanges: true
        onFileChanged: reload()
    }

    property FileView gtk4File: FileView {
        path: Quickshell.env("HOME") + "/.config/gtk-4.0/settings.ini"
        watchChanges: true
        onFileChanged: reload()
    }

    // Replaces one `key=...` line (matched to end of line) with a new
    // value, or appends it if the key isn't present at all yet - shared by
    // every write below rather than duplicating the same regex-replace
    // logic four times.
    function _setIniKey(file, key, value) {
        const text = file.text()
        const lineRegex = new RegExp("^" + key + "=.*$", "m")
        const newLine = key + "=" + value
        const newText = lineRegex.test(text) ? text.replace(lineRegex, newLine) : (text + "\n" + newLine + "\n")
        file.setText(newText)
    }

    // Xresources lines use "Key: value" (colon-space), not INI's "key=value"
    // - genuinely different syntax, so this doesn't just call _setIniKey
    // with a different separator character; the regex/replacement both
    // need their own colon-aware version. `xrdb -merge` afterward pushes
    // the change into the live X server's resource database immediately -
    // real and instant at that level, though see this file's own header
    // comment for why that still isn't the same as an app actually seeing
    // a new cursor.
    function _setXresourceKey(key, value) {
        const text = xresourcesFile.text()
        const lineRegex = new RegExp("^" + key + ":.*$", "m")
        const newLine = key + ": " + value
        const newText = lineRegex.test(text) ? text.replace(lineRegex, newLine) : (text + "\n" + newLine + "\n")
        xresourcesFile.setText(newText)
        xrdbMerger.command = ["xrdb", "-merge", xresourcesFile.path]
        xrdbMerger.running = true
    }

    property Process xrdbMerger: Process {}

    function setIconTheme(val) {
        configFile.adapter.iconTheme = val
        root._setIniKey(qt6ctFile, "icon_theme", val)
        root._setIniKey(gtk3File, "gtk-icon-theme-name", val)
        root._setIniKey(gtk4File, "gtk-icon-theme-name", val)
    }

    // ~/.icons/default/index.theme may not exist at all on a fresh install
    // (no prior cursor theme ever explicitly chosen) - _setIniKey's own
    // append-if-missing fallback still produces a valid two-line
    // [icon theme]/Inherits= file in that case, same shape as the one
    // already found on the reference machine, just without a pre-existing
    // [icon theme] header to preserve. The one real gap: if ~/.icons/
    // itself doesn't exist yet, FileView can create the file but not a
    // missing parent directory - a `mkdir -p ~/.icons/default` on a truly
    // bare system would be needed first, not attempted here since this
    // reference machine already has the directory.
    function setCursorTheme(val) {
        configFile.adapter.cursorTheme = val
        root._setIniKey(cursorIndexFile, "Inherits", val)
        root._setIniKey(gtk3File, "gtk-cursor-theme-name", val)
        root._setIniKey(gtk4File, "gtk-cursor-theme-name", val)
        root._setXresourceKey("Xcursor.theme", val)
    }

    function setCursorSize(val) {
        const size = Math.round(val)
        configFile.adapter.cursorSize = size
        root._setIniKey(gtk3File, "gtk-cursor-theme-size", size)
        root._setIniKey(gtk4File, "gtk-cursor-theme-size", size)
        root._setXresourceKey("Xcursor.size", size)
    }

    function setFontFamily(val) {
        configFile.adapter.fontFamily = val
        root._setIniKey(gtk3File, "gtk-font-name", val + " " + Math.round(root.fontSize))
        root._setIniKey(gtk4File, "gtk-font-name", val + " " + Math.round(root.fontSize))
    }

    function setFontSize(val) {
        configFile.adapter.fontSize = val
        const family = configFile.adapter.fontFamily || Qt.application.font.family
        root._setIniKey(gtk3File, "gtk-font-name", family + " " + Math.round(val))
        root._setIniKey(gtk4File, "gtk-font-name", family + " " + Math.round(val))
    }

    function setDefaultBrowser(val) {
        configFile.adapter.defaultBrowser = val
        browserSetter.command = ["xdg-settings", "set", "default-web-browser", val + ".desktop"]
        browserSetter.running = true
    }

    property Process browserSetter: Process {}

    // A honest limitation, confirmed live rather than assumed: this only
    // does a hard *QML* reload (tears down and rebuilds the whole
    // component tree within the same OS process - confirmed via `ps`, the
    // process id never changes) via Quickshell's own `reload(true)`. That's
    // real and useful on its own (every FileView re-reads fresh from disk,
    // including ones that don't `watchChanges`), but it does NOT re-init
    // Qt's own icon theme - QIcon's theme is resolved once, when
    // QGuiApplication itself first constructs, and a QML-level reload never
    // touches that. A genuine icon theme or GTK font change still needs a
    // real process restart (kill and relaunch `qs`, or a full logout/login)
    // to actually become visible - this button doesn't shortcut that, and
    // Settings says so rather than implying it does.
    function restartShell() {
        Quickshell.reload(true)
    }
}
