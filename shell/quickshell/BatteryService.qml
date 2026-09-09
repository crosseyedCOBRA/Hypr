pragma Singleton
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery/power-device status, adapted from Services/Hardware/
// BatteryService.qml (MIT licensed, v4.7.7 - see README.md's "Third-party
// code" section). Built on Quickshell's own `Quickshell.Services.UPower`
// module - a real D-Bus/UPower integration with zero Wayland or compositor
// coupling, works identically on X11 - so this is a straight architectural
// port, not a "build something simpler" rescope like WallpaperService or
// NightLightService needed. Requires the `upower` daemon running (already
// installed and active on the reference machine, confirmed via `upower -e`
// listing real devices) - see DEPENDENCIES.md.
//
// Broadened in one respect from the original: `primaryDevice` falls back to
// any present UPower battery-type device, not just ones flagged
// `isLaptopBattery` - this desktop has no laptop battery but does have a
// real one UPower already tracks (a wireless mouse/keyboard reporting
// through the kernel's HID++ driver, confirmed via `upower -e` listing
// `battery_hidpp_battery_0`), and restricting to laptop-only would have
// left this permanently untestable and hidden on the very machine used to
// verify it.
//
// Deliberately scoped down from the original in one way: dropped the
// Bluetooth-peripheral-battery merging (`qs.Services.Networking`'s
// BluetoothService, `bluetoothBatteries`, `isBluetoothDevice`, the
// Bluetooth-specific branches throughout) - Zaris's own Bluetooth module is
// built directly on Quickshell's native `Quickshell.Bluetooth` rather than
// a Noctalia-shaped wrapper, and whether its `BluetoothDevice` type exposes
// comparable per-device battery properties hasn't been checked yet; a
// real follow-up, not a silent drop. The low/critical-battery notification
// logic (`_hasNotified`/`checkBatteryNotification`/`notifyLevel` below) was
// kept, but rebuilt on `notify-send` instead of Noctalia's own
// `ToastService.showNotice(...)` - see that function's own comment for why.
// `I18n.tr(...)` calls flattened to plain English literals; icon selection
// returns Zaris's own raw Nerd Font glyph codepoints directly (matching
// every other icon usage in this codebase) rather than Noctalia's semantic
// icon-name strings.
Singleton {
    id: root

    readonly property var primaryDevice: UPower.displayDevice.isPresent ? UPower.displayDevice : (laptopBatteries.length > 0 ? laptopBatteries[0] : (otherBatteries.length > 0 ? otherBatteries[0] : null))
    readonly property real batteryPercentage: getPercentage(primaryDevice)
    readonly property bool batteryCharging: isCharging(primaryDevice)
    readonly property bool batteryPluggedIn: isPluggedIn(primaryDevice)
    readonly property bool batteryReady: isDeviceReady(primaryDevice)
    readonly property bool batteryPresent: isDevicePresent(primaryDevice)
    readonly property string batteryIcon: getIcon(batteryPercentage, batteryCharging, batteryPluggedIn, batteryReady)

    // Hand-edit-only for now, same precedent as modules.json's per-module
    // "screens" pinning and nightlight.json's schedule settings.
    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/quickshell/battery.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // Re-check notification thresholds on every load/reload - the
        // proven-reliable hook (see NightLightService.qml's own hot-reload
        // verification) rather than assuming individual threshold
        // property-changed signals fire promptly on their own.
        onLoaded: root.checkBatteryNotification()

        adapter: JsonAdapter {
            property real warningThreshold: 20
            property real criticalThreshold: 10
        }
    }

    readonly property real warningThreshold: configFile.adapter.warningThreshold
    readonly property real criticalThreshold: configFile.adapter.criticalThreshold

    // No caller needed these until Settings' new Battery tab - the config
    // properties/checkBatteryNotification() re-check were already wired
    // up (battery.json was presumably meant to be hand-edited until now).
    function setWarningThreshold(val) {
        configFile.adapter.warningThreshold = val
    }

    function setCriticalThreshold(val) {
        configFile.adapter.criticalThreshold = val
    }

    readonly property var laptopBatteries: UPower.devices.values.filter(d => d.isLaptopBattery).sort((x, y) => {
        if (x.nativePath.includes("DisplayDevice"))
            return -1
        if (y.nativePath.includes("DisplayDevice"))
            return 1
        return x.nativePath.localeCompare(y.nativePath, undefined, { numeric: true })
    })

    // Any other present, non-line-power device UPower knows about (wireless
    // mice/keyboards, headsets, etc., surfaced via the kernel's HID++/HID
    // drivers) - used as a fallback when there's no laptop battery at all,
    // so a real peripheral battery isn't left permanently hidden on a
    // desktop. Matches Noctalia's own `deviceModel` filter (any type other
    // than LinePower, not specifically `UPowerDeviceType.Battery`) -
    // confirmed necessary live: this machine's real device (a wireless
    // mouse reporting through the kernel's HID++ driver, nativePath
    // `hidpp_battery_0`) reports `type: Mouse`, not `type: Battery`.
    readonly property var otherBatteries: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent)

    function isDevicePresent(device) {
        if (!device)
            return false
        if (device.type !== undefined) {
            if (device.type === UPowerDeviceType.Battery && device.isPresent !== undefined)
                return device.isPresent === true
            return device.ready && device.percentage !== undefined
        }
        return false
    }

    function isDeviceReady(device) {
        if (!isDevicePresent(device))
            return false
        return device.ready && device.percentage !== undefined
    }

    function getPercentage(device) {
        if (!device)
            return -1
        return Math.round((device.percentage || 0) * 100)
    }

    function isCharging(device) {
        if (!device || device.state === undefined)
            return false
        return device.state === UPowerDeviceState.Charging
    }

    function isPluggedIn(device) {
        if (!device || device.state === undefined)
            return false
        return device.state === UPowerDeviceState.FullyCharged || device.state === UPowerDeviceState.PendingCharge
    }

    function isCriticalBattery(device) {
        return (!isCharging(device) && !isPluggedIn(device)) && getPercentage(device) <= criticalThreshold
    }

    function isLowBattery(device) {
        return (!isCharging(device) && !isPluggedIn(device)) && getPercentage(device) <= warningThreshold && getPercentage(device) > criticalThreshold
    }

    // Low/critical-battery desktop notifications - NOT routed through
    // Noctalia's own ToastService.showNotice(...) (the original file's
    // approach), since porting that would mean also porting its entire
    // Modules/Toast/{Toast,ToastOverlay,ToastScreen}.qml UI, and two of
    // those three are themselves built on Quickshell.Wayland layer-shell
    // positioning - a real Wayland-coupling gap, same category as
    // NightLightService's wlsunset dependency. More importantly, it would
    // be genuinely redundant infrastructure: Zaris already runs `dunst` as
    // its notification daemon (see DEPENDENCIES.md) and already calls
    // `notify-send` for exactly this kind of transient message
    // (screenshot.sh's "screenshot taken" notice) - so this reuses that
    // same established mechanism instead of building a parallel one.
    property var _hasNotified: ({ low: false, critical: false })

    function checkBatteryNotification() {
        if (!isDeviceReady(primaryDevice))
            return

        if (isCharging(primaryDevice) || isPluggedIn(primaryDevice)) {
            _hasNotified = { low: false, critical: false }
            return
        }

        if (isCriticalBattery(primaryDevice)) {
            if (!_hasNotified.critical)
                notifyLevel("critical")
            _hasNotified = { low: true, critical: true }
        } else if (isLowBattery(primaryDevice)) {
            if (!_hasNotified.low)
                notifyLevel("low")
            _hasNotified = { low: true, critical: false }
        } else {
            _hasNotified = { low: false, critical: false }
        }
    }

    function notifyLevel(level) {
        const name = root.getDeviceName(primaryDevice) || "Battery"
        const title = level === "critical" ? name + " critically low" : name + " low"
        const urgency = level === "critical" ? "critical" : "normal"
        Quickshell.execDetached(["notify-send", "-u", urgency, "-a", "Zaris", title, root.batteryPercentage + "% remaining"])
    }

    Connections {
        target: root
        function onBatteryPercentageChanged() { root.checkBatteryNotification() }
        function onBatteryChargingChanged() { root.checkBatteryNotification() }
        function onBatteryPluggedInChanged() { root.checkBatteryNotification() }
        // Also re-check on a hand-edited threshold change (battery.json is
        // watchChanges-hot-reloadable, same as nightlight.json) rather than
        // waiting for the next real percentage/state change to notice a
        // newly-lowered threshold.
        function onWarningThresholdChanged() { root.checkBatteryNotification() }
        function onCriticalThresholdChanged() { root.checkBatteryNotification() }
    }

    function getDeviceName(device) {
        if (!isDeviceReady(device))
            return ""
        if (device.isLaptopBattery) {
            if (laptopBatteries.length > 1 && device.nativePath) {
                if (device.nativePath === "DisplayDevice")
                    return "All Batteries"
                const match = device.nativePath.match(/(\d+)$/)
                if (match)
                    return "Battery " + (parseInt(match[1]) + 1)
            }
            return "Battery"
        }
        if (device.model)
            return device.model
        return ""
    }

    // Raw Nerd Font glyphs (nf-fa-battery-*), matching every other icon
    // usage in this codebase - not semantic names.
    function getIcon(percent, charging, pluggedIn, isReady) {
        if (!isReady)
            return "" // battery-empty (used as an "unknown/not ready" fallback too)
        if (charging || pluggedIn)
            return "" // plug
        if (percent >= 87)
            return "" // battery-full
        if (percent >= 62)
            return "" // battery-three-quarters
        if (percent >= 37)
            return "" // battery-half
        if (percent >= 12)
            return "" // battery-quarter
        return "" // battery-empty
    }

    function getTimeRemainingText(device) {
        if (!isDeviceReady(device))
            return "No battery detected"
        if (isPluggedIn(device))
            return "Plugged in"
        if (device.timeToFull > 0)
            return formatDuration(device.timeToFull) + " until full"
        if (device.timeToEmpty > 0)
            return formatDuration(device.timeToEmpty) + " left"
        return "Idle"
    }

    // Seconds -> "Xh Ym" / "Ym", no external formatting helper needed.
    function formatDuration(seconds) {
        const totalMinutes = Math.round(seconds / 60)
        const hours = Math.floor(totalMinutes / 60)
        const minutes = totalMinutes % 60
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }
}
