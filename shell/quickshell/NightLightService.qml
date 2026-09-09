pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Scheduled day/night service, extending the existing manual NightLight.qml
// on/off toggle rather than replacing it - fulfills the "extend, don't
// break, the current toggle" note from the Noctalia-port backlog. NOT a
// port of Noctalia's Services/Location/NightLightService.qml, despite the
// same filename/purpose - that file is built entirely around spawning and
// supervising a long-running `wlsunset` daemon process (Wayland-only,
// invisible to a Quickshell.Wayland-import grep since the coupling is
// purely in shell commands, same category of gap `ClipboardService.qml`'s
// cliphist/wl-copy/wtype dependency was), including real crash-restart
// bookkeeping that has no equivalent need here.
//
// `redshift` (already used by NightLight.qml's manual toggle) has no
// direct equivalent to wlsunset's own `-S`/`-s` manual sunrise/sunset-time
// flags for a long-running daemon - its continuous mode is built around
// real solar-position calculation from a lat/long (`-l LAT:LON` or
// `-l geoclue2`), which would mean building a LocationService first, the
// same dependency DarkModeService was already deferred for. So rather than
// a continuous daemon, this ports just the genuinely portable piece of
// Noctalia's file - the manual-schedule time math (`timeToMinutes`,
// `isCurrentlyNight`, `msUntilNextBoundary`, kept close to verbatim, pure
// JS with zero external coupling) - and drives NightLight.qml's existing
// one-shot `redshift -O <temp>` / `redshift -x` calls from a Timer that
// re-fires exactly at the next sunset/sunrise boundary, rather than
// keeping any process running continuously in between.
//
// Scheduling is opt-in and hand-edit-only for now (no Settings.qml GUI
// yet), same precedent as modules.json's per-module "screens" pinning -
// edit ~/.config/quickshell/nightlight.json directly to enable it.
Singleton {
    id: root

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nightlight.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.applySchedule()

        adapter: JsonAdapter {
            id: cfg
            property bool scheduleEnabled: false
            property string sunset: "18:00"
            property string sunrise: "06:00"
            property int nightTemp: 4500
        }
    }

    readonly property bool scheduleEnabled: configFile.adapter.scheduleEnabled
    readonly property string sunset: configFile.adapter.sunset
    readonly property string sunrise: configFile.adapter.sunrise
    readonly property int nightTemp: configFile.adapter.nightTemp

    // No caller needed these until Settings' new Night Light tab - hand-
    // editing nightlight.json was the only way to change any of this
    // before now (see this file's own header comment). Each setter
    // re-runs applySchedule() so a change takes effect immediately rather
    // than waiting for the next boundary timer tick.
    function setScheduleEnabled(val) {
        configFile.adapter.scheduleEnabled = val
        applySchedule()
    }

    function setSunset(val) {
        configFile.adapter.sunset = val
        applySchedule()
    }

    function setSunrise(val) {
        configFile.adapter.sunrise = val
        applySchedule()
    }

    function setNightTemp(val) {
        configFile.adapter.nightTemp = val
        // If currently in the night state, re-apply immediately so a
        // color-temperature change is visible right away rather than only
        // taking effect at the next sunset - the schedule's on/off timing
        // itself is unaffected, just the temperature redshift is called
        // with.
        if (NightLightState.active)
            Quickshell.execDetached(["redshift", "-O", String(val)])
    }

    // Ported near-verbatim from Noctalia's NightLightService.qml - pure
    // time-of-day math, no external coupling.
    function timeToMinutes(timeStr) {
        const parts = timeStr.split(":").map(Number)
        return parts[0] * 60 + parts[1]
    }

    function isCurrentlyNight() {
        const now = new Date()
        const nowMin = now.getHours() * 60 + now.getMinutes()
        const sunsetMin = timeToMinutes(root.sunset)
        const sunriseMin = timeToMinutes(root.sunrise)

        if (sunsetMin < sunriseMin) {
            // Inverted: e.g. sunset=03:00, sunrise=07:00 -> night is [03:00, 07:00)
            return nowMin >= sunsetMin && nowMin < sunriseMin
        } else {
            // Normal: e.g. sunset=18:00, sunrise=06:00 -> night is [18:00, 06:00)
            return nowMin >= sunsetMin || nowMin < sunriseMin
        }
    }

    function msUntilNextBoundary() {
        const now = new Date()
        const nowMin = now.getHours() * 60 + now.getMinutes()
        const sunsetMin = timeToMinutes(root.sunset)
        const sunriseMin = timeToMinutes(root.sunrise)

        const targetMin = isCurrentlyNight() ? sunriseMin : sunsetMin
        let diffMin = targetMin - nowMin
        if (diffMin <= 0)
            diffMin += 1440

        return diffMin * 60 * 1000 - now.getSeconds() * 1000 - now.getMilliseconds()
    }

    Timer {
        id: boundaryTimer
        repeat: false
        onTriggered: root.applySchedule()
    }

    function applySchedule() {
        boundaryTimer.stop()

        if (!root.scheduleEnabled)
            return

        const night = root.isCurrentlyNight()
        if (night !== NightLightState.active) {
            NightLightState.active = night
            if (night)
                Quickshell.execDetached(["redshift", "-O", String(root.nightTemp)])
            else
                Quickshell.execDetached(["redshift", "-x"])
        }

        boundaryTimer.interval = Math.max(root.msUntilNextBoundary(), 1000)
        boundaryTimer.start()
    }

    Component.onCompleted: applySchedule()
}
