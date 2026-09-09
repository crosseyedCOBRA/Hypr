pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User-customizable color theme, backed by two separate files since it
// spans two genuinely different config surfaces:
//
//   ~/.config/quickshell/colors.json (JSON, FileView+JsonAdapter, same
//   hand-editable-plus-Settings-GUI pattern as every other *Config.qml) -
//   the five shell-side roles Colors.qml's own header comment already
//   names as "the three accent colors already in rotation across bar
//   widgets" (primary/secondary/tertiary) plus text/background. Colors.qml
//   itself reads these instead of hardcoding them, so every one of the ~50
//   files that already reference Colors.bg/Colors.text/Colors.blue/etc.
//   picks up a theme change automatically - no other file needs touching.
//
//   ~/.config/zaris/zaris.conf's own `col.active_border=0xAARRGGBB` line -
//   a genuinely different, WM-level (C++) setting, not something
//   Quickshell's JSON configs have any reach into. Read/written here as
//   plain text via FileView.text()/setText() (same mechanism
//   HostService.qml already uses to read /etc/os-release) rather than
//   JsonAdapter, with a regex that only ever touches that one line -
//   preserving the file's alpha byte and everything else in it untouched.
//   The WM already hot-reloads zaris.conf on mtime change
//   (ConfigManager::tick()), so this takes effect live like the JSON
//   configs do, with one caveat: an *already-focused* window's border only
//   actually repaints on its next real focus change (setEffectiveBorderColor
//   is only called from focus-change handling in windowManager.cpp) - a
//   minor, WM-level characteristic, not a bug in this file.
QtObject {
    id: root

    property FileView colorsFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property string primary: "#5b7fd6"
            property string secondary: "#4da4a6"
            property string tertiary: "#c55a63"
            property string text: "#e8e6f0"
            property string background: "#0c0b1a"
            // Empty (the default) means "follow background" - most users
            // want the bar to just match the rest of the shell, so this is
            // an override rather than a required sixth color to fill in.
            // See barBackground below and Colors.barBg.
            property string barBackground: ""
        }
    }

    readonly property string primary: colorsFile.adapter.primary || "#5b7fd6"
    readonly property string secondary: colorsFile.adapter.secondary || "#4da4a6"
    readonly property string tertiary: colorsFile.adapter.tertiary || "#c55a63"
    readonly property string text: colorsFile.adapter.text || "#e8e6f0"
    readonly property string background: colorsFile.adapter.background || "#0c0b1a"
    // Empty string (not a fallback hex) when unset - Colors.barBg is what
    // actually resolves "unset -> follow background", same reasoning
    // BarConfig.launcherIcon's own fallback-to-default already established.
    // Kept as a raw pass-through here (not defaulted to a color) so the
    // Settings UI/Colors.barBg can tell "genuinely unset" apart from "set
    // to a color that happens to match the default".
    readonly property string barBackground: colorsFile.adapter.barBackground || ""

    function setPrimary(val) { colorsFile.adapter.primary = val }
    function setSecondary(val) { colorsFile.adapter.secondary = val }
    function setTertiary(val) { colorsFile.adapter.tertiary = val }
    function setText(val) { colorsFile.adapter.text = val }
    function setBackground(val) { colorsFile.adapter.background = val }
    function setBarBackground(val) { colorsFile.adapter.barBackground = val }

    // --- window border accent (zaris.conf, not colors.json - see above) ---

    property FileView zarisConfFile: FileView {
        path: Quickshell.env("HOME") + "/.config/zaris/zaris.conf"
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var _activeBorderMatch: {
        const t = zarisConfFile.text ? zarisConfFile.text() : ""
        return t.match(/^col\.active_border=0x([0-9a-fA-F]{2})([0-9a-fA-F]{6})/m)
    }

    readonly property string borderAccent: root._activeBorderMatch ? "#" + root._activeBorderMatch[2] : "#3bb2d4"

    function setBorderAccent(hex) {
        const rgb = hex.replace("#", "").toLowerCase()
        if (rgb.length !== 6)
            return
        const text = zarisConfFile.text()
        const lineRegex = /^col\.active_border=0x[0-9a-fA-F]{2}[0-9a-fA-F]{6}.*$/m
        const alpha = root._activeBorderMatch ? root._activeBorderMatch[1] : "77"
        const newLine = "col.active_border=0x" + alpha + rgb
        const newText = lineRegex.test(text)
            ? text.replace(lineRegex, newLine)
            : text + "\n" + newLine + "\n"
        zarisConfFile.setText(newText)
    }

    // --- built-in presets ---

    // A handful of well-known community palettes as one-click starting
    // points, each mapped onto the same five roles plus a matching border
    // accent - "Zaris Default" is exactly today's shipped values (including
    // the live border color already hand-picked to match the Artix logo),
    // so applying it is a genuine reset rather than a close approximation.
    // Fixed/non-removable - see customPresets below for the user-saveable
    // slots, which is where the actual add/remove capability lives. Kept
    // hardcoded rather than folded into the same persisted file, so there's
    // always a guaranteed way back to a known-good starting point even if
    // a user empties out every custom preset they've saved.
    readonly property var builtinPresets: [
        { id: "default", name: "Zaris Default", primary: "#5b7fd6", secondary: "#4da4a6", tertiary: "#c55a63", text: "#e8e6f0", background: "#0c0b1a", borderAccent: "#3bb2d4" },
        { id: "nord", name: "Nord", primary: "#88c0d0", secondary: "#81a1c1", tertiary: "#b48ead", text: "#eceff4", background: "#2e3440", borderAccent: "#88c0d0" },
        { id: "dracula", name: "Dracula", primary: "#bd93f9", secondary: "#ff79c6", tertiary: "#50fa7b", text: "#f8f8f2", background: "#282a36", borderAccent: "#bd93f9" },
        { id: "catppuccin", name: "Catppuccin Mocha", primary: "#89b4fa", secondary: "#94e2d5", tertiary: "#f38ba8", text: "#cdd6f4", background: "#1e1e2e", borderAccent: "#89b4fa" },
        { id: "gruvbox", name: "Gruvbox Dark", primary: "#83a598", secondary: "#b8bb26", tertiary: "#fe8019", text: "#ebdbb2", background: "#282828", borderAccent: "#fabd2f" }
    ]

    // User-saved presets - "Save current colors as a new named preset" in
    // Settings' Colors tab. Own small file rather than folded into
    // colors.json (colors.json is "what's live right now", this is "a
    // library of things that could become live") - same FileView+
    // JsonAdapter pattern as every other *Config.qml.
    property FileView presetsFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/presets.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            property var custom: []
        }
    }

    readonly property var customPresets: presetsFile.adapter.custom || []

    // The full picker list Settings' Colors tab renders - built-ins first,
    // then whatever's been saved, capped at 12 total between the two (see
    // addCustomPreset below for where that cap is actually enforced).
    readonly property var presets: root.builtinPresets.concat(root.customPresets)

    readonly property int maxPresets: 12

    // Snapshots the five colors + border accent currently live (not
    // whatever's in a Settings text field mid-edit) under a user-typed
    // name. Silently no-ops past the cap - Settings' own Save button
    // disables itself at the cap instead of ever calling this past it, so
    // this is a backstop, not the primary guard.
    function addCustomPreset(name) {
        if (root.presets.length >= root.maxPresets)
            return
        const trimmed = (name || "").trim()
        if (trimmed === "")
            return
        const entry = {
            id: "custom-" + Date.now(),
            name: trimmed,
            primary: root.primary,
            secondary: root.secondary,
            tertiary: root.tertiary,
            text: root.text,
            background: root.background,
            borderAccent: root.borderAccent
        }
        presetsFile.adapter.custom = root.customPresets.concat([entry])
    }

    // Built-ins aren't removable at all (see builtinPresets' own comment) -
    // this only ever finds a match among customPresets, a plain no-op
    // otherwise.
    function removeCustomPreset(id) {
        presetsFile.adapter.custom = root.customPresets.filter(function (p) { return p.id !== id })
    }

    // Applying a preset means six rapid-fire writes (five colorsFile
    // fields plus the border accent) in one synchronous call - confirmed
    // live, repeatedly, that calling the setters straight through drops
    // some of them silently and non-deterministically (which ones varied
    // run to run - not always the same fields): each setter's own
    // onAdapterUpdated: writeAdapter() writes the file, which can
    // re-trigger this same FileView's own watchChanges/onFileChanged:
    // reload() before the next setter in the sequence has run, and that
    // reload can stomp an in-flight property change with what was still on
    // disk a moment earlier. Toggling watchChanges off for the whole batch
    // was tried first and looked like it fixed it in one test, but a
    // repeat run dropped fields again just the same - the race window
    // wasn't reliably closed, just sometimes missed. Spacing each setter
    // out onto its own Timer tick (a real, if slightly less instant, fix)
    // gives each write+reload cycle time to fully settle before the next
    // property changes - confirmed fixing it live across many repeated
    // preset applications with no dropped fields, unlike the watchChanges
    // approach.
    property var _presetQueue: []

    function applyPreset(id) {
        const p = root.presets.find(function (x) { return x.id === id })
        if (!p)
            return
        root._presetQueue = [
            function () { root.setPrimary(p.primary) },
            function () { root.setSecondary(p.secondary) },
            function () { root.setTertiary(p.tertiary) },
            function () { root.setText(p.text) },
            function () { root.setBackground(p.background) },
            function () { root.setBorderAccent(p.borderAccent) },
            // Reset any custom bar-color override back to "follow
            // background" - a preset should give a coherent full look,
            // not leave one mismatched custom bar color behind from
            // whatever was set before switching presets.
            function () { root.setBarBackground("") }
        ]
        presetStepTimer.start()
    }

    property Timer presetStepTimer: Timer {
        interval: 60
        repeat: true
        onTriggered: {
            if (root._presetQueue.length === 0) {
                stop()
                return
            }
            const step = root._presetQueue.shift()
            step()
        }
    }
}
