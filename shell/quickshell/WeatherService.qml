pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Current-conditions weather for the Control Center, deferred from the
// seventh Control Center pass specifically so it wouldn't be bundled into
// an already-large change - see ROADMAP.md. No API key anywhere: open-meteo
// (api.open-meteo.com/v1/forecast, plus its own geocoding-api.open-meteo.com
// for turning a typed city name into coordinates) is free and keyless for
// this volume of use, confirmed live; ipinfo.io/json is the same for the
// one-time-per-refresh IP-based location lookup used when no manual
// location is set. Both fetched with QML's own built-in XMLHttpRequest
// (confirmed working - full outbound HTTPS access, no curl subprocess
// needed) rather than shelling out, since there's no output here that's
// easier to get from a CLI tool than a plain JSON GET.
QtObject {
    id: root

    // Same FileView+JsonAdapter pattern as identity.json/modules.json - one
    // small hand-editable file. Empty string means "auto-detect via IP";
    // anything else is a city/place name string passed straight to
    // open-meteo's geocoding API.
    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/weather.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            property string manualLocationQuery: ""
            property bool hideLocation: false
        }
    }

    readonly property string manualLocationQuery: configFile.adapter.manualLocationQuery
    // For anyone who doesn't want their city name visible in a widget that
    // can end up on screen in a screenshot/stream - WeatherWidget.qml
    // (shared by Control Center and the calendar flyout) respects this,
    // still showing the temperature/condition/hi-lo, just not the place
    // name itself.
    readonly property bool hideLocation: configFile.adapter.hideLocation === true

    function setManualLocation(query) {
        configFile.adapter.manualLocationQuery = query
        refresh()
    }

    function useAutoLocation() {
        configFile.adapter.manualLocationQuery = ""
        refresh()
    }

    function setHideLocation(val) {
        configFile.adapter.hideLocation = val
    }

    property bool loading: false
    property bool haveData: false
    property string errorText: ""

    property string locationName: ""
    property real latitude: 0
    property real longitude: 0

    property real temperatureF: 0
    property real highF: 0
    property real lowF: 0
    property int weatherCode: 0
    property bool isDay: true

    // WMO weather codes (open-meteo's `weather_code`) collapsed to the
    // short descriptions used by most weather services' own code tables.
    function conditionText(code) {
        if (code === 0) return "Clear"
        if (code === 1) return "Mostly Clear"
        if (code === 2) return "Partly Cloudy"
        if (code === 3) return "Overcast"
        if (code === 45 || code === 48) return "Fog"
        if (code === 51 || code === 53 || code === 55) return "Drizzle"
        if (code === 56 || code === 57) return "Freezing Drizzle"
        if (code === 61 || code === 63 || code === 65) return "Rain"
        if (code === 66 || code === 67) return "Freezing Rain"
        if (code === 71 || code === 73 || code === 75 || code === 77) return "Snow"
        if (code === 80 || code === 81 || code === 82) return "Rain Showers"
        if (code === 85 || code === 86) return "Snow Showers"
        if (code === 95 || code === 96 || code === 99) return "Thunderstorm"
        return "Unknown"
    }

    readonly property string conditionTextCurrent: conditionText(weatherCode)

    // Nerd Font "Weather Icons" block (0xe300-0xe3e3) - confirmed present
    // glyph-by-glyph in the installed JetBrainsMono Nerd Font before
    // picking these codepoints (a wrong guess here would render as a blank
    // tofu box with zero warning, the same class of silent failure
    // documented elsewhere in this file's own git history for Nerd Font
    // glyphs in general).
    function iconGlyph(code, day) {
        if (code === 0 || code === 1)
            return day ? "" : "" // day_sunny / night_clear
        if (code === 2)
            return day ? "" : "" // day_cloudy / night_cloudy
        if (code === 3)
            return "" // cloudy
        if (code === 45 || code === 48)
            return day ? "" : "" // day_fog / night_fog
        if (code === 51 || code === 53 || code === 55)
            return day ? "" : "" // day_sprinkle / night_sprinkle
        if (code === 56 || code === 57 || code === 66 || code === 67)
            return day ? "" : "" // day_rain_mix / night_rain_mix
        if (code === 61 || code === 63 || code === 65)
            return day ? "" : "" // day_rain / night_rain
        if (code === 71 || code === 73 || code === 75 || code === 77 || code === 85 || code === 86)
            return day ? "" : "" // day_snow / night_snow
        if (code === 80 || code === 81 || code === 82)
            return day ? "" : "" // day_showers / night_showers
        if (code === 95 || code === 96 || code === 99)
            return day ? "" : "" // day_thunderstorm / night_thunderstorm
        return "" // weather-na
    }

    readonly property string iconGlyphCurrent: iconGlyph(weatherCode, isDay)

    function refresh() {
        if (root.loading)
            return
        root.loading = true
        root.errorText = ""

        if (manualLocationQuery.length > 0)
            geocodeManualLocation()
        else
            geolocateByIp()
    }

    function geocodeManualLocation() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                if (xhr.status !== 200)
                    throw new Error("geocoding HTTP " + xhr.status)
                const data = JSON.parse(xhr.responseText)
                const match = data.results && data.results[0]
                if (!match)
                    throw new Error("no match for \"" + manualLocationQuery + "\"")
                root.locationName = match.name + (match.admin1 ? ", " + match.admin1 : "")
                fetchWeather(match.latitude, match.longitude)
            } catch (e) {
                root.loading = false
                root.errorText = "" + e
            }
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(manualLocationQuery))
        xhr.send()
    }

    function geolocateByIp() {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                if (xhr.status !== 200)
                    throw new Error("ipinfo HTTP " + xhr.status)
                const data = JSON.parse(xhr.responseText)
                const loc = (data.loc || "").split(",")
                if (loc.length !== 2)
                    throw new Error("ipinfo returned no location")
                root.locationName = data.city ? data.city + (data.region ? ", " + data.region : "") : "Unknown Location"
                fetchWeather(parseFloat(loc[0]), parseFloat(loc[1]))
            } catch (e) {
                root.loading = false
                root.errorText = "" + e
            }
        }
        xhr.open("GET", "https://ipinfo.io/json")
        xhr.send()
    }

    function fetchWeather(lat, lon) {
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            root.loading = false
            try {
                if (xhr.status !== 200)
                    throw new Error("forecast HTTP " + xhr.status)
                const data = JSON.parse(xhr.responseText)
                root.latitude = lat
                root.longitude = lon
                root.temperatureF = data.current.temperature_2m
                root.weatherCode = data.current.weather_code
                root.isDay = data.current.is_day === 1
                root.highF = data.daily.temperature_2m_max[0]
                root.lowF = data.daily.temperature_2m_min[0]
                root.haveData = true
            } catch (e) {
                root.errorText = "" + e
            }
        }
        xhr.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min"
            + "&temperature_unit=fahrenheit&timezone=auto&forecast_days=1")
        xhr.send()
    }

    property Timer refreshTimer: Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
