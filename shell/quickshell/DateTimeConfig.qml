pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User-configurable date/time display - first day of the week (drives
// CalendarWidget.qml's month grid, shared by both Control Center's Calendar
// section and CalendarFlyout.qml's popup) and the bar clock's date/time
// format (BarClockText.qml). Same FileView+JsonAdapter pattern as every
// other *Config.qml, backed by its own datetime.json rather than folding
// into defaults.json - this is display preference, not a "default app"
// concept.
//
// Format choices are a fixed dropdown of presets rather than a free-form
// Qt date-format string field - keeps this discoverable/foolproof (an
// invalid hand-typed format string would silently mis-render or show
// literal format characters) rather than exposing Qt.formatDateTime's full
// pattern syntax directly.
QtObject {
    id: root

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/datetime.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            property int firstDayOfWeek: 0 // 0 = Sunday, 1 = Monday
            property string dateFormat: "dddd MMMM d yyyy"
            property string timeFormat: "HH:mm"
        }
    }

    readonly property int firstDayOfWeek: configFile.adapter.firstDayOfWeek === 1 ? 1 : 0
    readonly property string dateFormat: configFile.adapter.dateFormat || "dddd MMMM d yyyy"
    readonly property string timeFormat: configFile.adapter.timeFormat || "HH:mm"

    // Combined format for the bar clock (BarClockText.qml) - date and time
    // halves stay independently configurable but are always shown together
    // there, same as today's hardcoded "dddd MMMM d yyyy HH:mm".
    readonly property string clockFormat: root.dateFormat + " " + root.timeFormat

    // Rendered against "now" once at load (not re-evaluated per-minute the
    // way the live clock is) purely for the dropdown's own preview text -
    // good enough for a settings list, and keeps every preset's preview
    // honest/correct for today's actual date rather than a hand-typed
    // example that could go stale or not match the user's locale.
    readonly property var dateFormatOptions: {
        const now = new Date()
        const formats = ["dddd MMMM d yyyy", "ddd, MMM d yyyy", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "d MMMM yyyy"]
        return formats.map(function (f) { return { key: f, name: Qt.formatDateTime(now, f) } })
    }

    readonly property var timeFormatOptions: {
        const now = new Date()
        const formats = ["HH:mm", "h:mm AP"]
        return formats.map(function (f) { return { key: f, name: Qt.formatDateTime(now, f) } })
    }

    // Keys are strings, not the raw 0/1 ints - NComboBox.currentKey/model
    // keys are always compared with strict equality against a `string`
    // property, so a numeric key would never match.
    readonly property var firstDayOfWeekOptions: [
        { key: "0", name: "Sunday" },
        { key: "1", name: "Monday" }
    ]

    function setFirstDayOfWeek(val) {
        configFile.adapter.firstDayOfWeek = parseInt(val, 10)
    }

    function setDateFormat(val) {
        configFile.adapter.dateFormat = val
    }

    function setTimeFormat(val) {
        configFile.adapter.timeFormat = val
    }
}
