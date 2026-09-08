pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared power-profile state, backed by power-profiles-daemon's own
// `powerprofilesctl` CLI (its standard D-Bus-backed frontend) - the other
// half of "we can add in weather and power profiles" from the fourth
// Control Center pass, deferred alongside weather at the time.
//
// Not yet installed on this machine (confirmed via `which powerprofilesctl`
// - it's packaged for Arch/Artix as `power-profiles-daemon`, with a
// dedicated `-openrc` init-script package too, matching this machine's
// OpenRC init system same as every other backing service this project has
// added), so built ahead of that the same way DDC brightness detection and
// ClipboardHistoryService's clipnotify check were: a Quickshell `Process`
// simply never fires `onExited`/`onStreamFinished` when its command binary
// doesn't exist (confirmed elsewhere in this codebase - see
// BrightnessService.qml's own `ddcutil detect` comment), so this sits
// harmlessly inert (`currentProfile` stays `""`, no tile shows as active)
// rather than erroring, until the daemon is installed and running.
//
// The three profile names (`power-saver`/`balanced`/`performance`) are a
// stable, versioned part of power-profiles-daemon's D-Bus API, not
// something to parse out of `powerprofilesctl list`'s human-oriented text
// output - hardcoding them here is lower-risk than depending on that
// format staying exactly parseable. `performance` is optional per-machine
// (only present when some driver reports it usable) - `powerprofilesctl
// set performance` simply fails harmlessly on a machine without it, same
// "no crash, just inert" shape as the whole feature being uninstalled.
QtObject {
    id: root

    readonly property var profiles: ["power-saver", "balanced", "performance"]
    property string currentProfile: ""

    function profileLabel(name) {
        if (name === "power-saver") return "Saver"
        if (name === "performance") return "Performance"
        return "Balanced"
    }

    // Font Awesome glyphs, confirmed present in the installed Nerd Font
    // (fontTools cmap check) before picking them - see WeatherService.qml's
    // header comment for why that check matters more than it sounds like
    // it should.
    function profileIcon(name) {
        if (name === "power-saver") return "" // leaf
        if (name === "performance") return "" // bolt
        return "" // balance-scale
    }

    Component.onCompleted: queryProc.running = true

    property Process queryProc: Process {
        id: queryProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.currentProfile = this.text.trim()
        }
    }

    // Same optimistic-update shape as StayAwake.qml/Dnd.qml's own
    // toggle() functions - the UI reflects the requested state immediately
    // rather than waiting on a round trip, consistent with every other
    // instant-feeling toggle in this codebase.
    function setProfile(name) {
        root.currentProfile = name
        Quickshell.execDetached(["powerprofilesctl", "set", name])
    }

    // ControlCenter.qml's tile is a single cycling button (one click steps
    // to the next profile), not the original three-way segmented row this
    // shipped with - a user request after seeing the first version live.
    // Falls back to the list's first entry when currentProfile is still ""
    // (nothing queried back yet, or the daemon isn't installed), so the
    // very first click always lands on a real profile instead of no-op'ing.
    function cycleProfile() {
        const idx = root.profiles.indexOf(root.currentProfile)
        const next = root.profiles[(idx + 1) % root.profiles.length]
        root.setProfile(next)
    }
}
