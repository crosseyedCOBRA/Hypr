pragma Singleton
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io

// Per-monitor brightness control - external DDC/CI-capable monitors via
// `ddcutil`, internal laptop backlight via `brightnessctl`, and Apple
// Studio Display support via `asdbctl` - adapted from Services/Hardware/
// BrightnessService.qml (MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section). Genuinely portable as-is (all three tools
// are plain Linux CLI programs, zero Wayland/compositor coupling), so
// this is a straight architectural port like BatteryService.qml, not a
// "build something simpler" rescope.
//
// NEITHER `ddcutil` NOR `brightnessctl` IS INSTALLED ON THE REFERENCE
// MACHINE, and it has no `/sys/class/backlight` device either - every
// path here is designed to degrade gracefully (empty device lists,
// disabled controls) when its backing tool is missing, and that
// degradation was verified live (loads cleanly, `ddcutil detect` and the
// backlight-scan both correctly report nothing found, no errors), but the
// actual brightness-changing commands themselves could NOT be verified
// end-to-end here. See DEPENDENCIES.md's "Optional dependencies" section -
// install `ddcutil` for external-monitor brightness or `brightnessctl` for
// an internal laptop panel, whichever matches your hardware, then re-test.
//
// Stripped of `Settings.data.brightness.*` (now a hand-edit-only
// `brightness.json`, same precedent as `nightlight.json`/`battery.json`:
// `enableDdcSupport`, `enforceMinimum`, `brightnessStep`,
// `backlightDeviceMappings`) and `Logger.*` calls. No I18n calls existed
// in the original file.
Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false
    property list<var> availableBacklightDevices: []

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/quickshell/brightness.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: cfg
            property bool enableDdcSupport: true
            property bool enforceMinimum: true
            property int brightnessStep: 5
            property var backlightDeviceMappings: []
        }
    }

    readonly property bool enableDdcSupport: configFile.adapter.enableDdcSupport
    readonly property bool enforceMinimum: configFile.adapter.enforceMinimum
    readonly property int brightnessStep: configFile.adapter.brightnessStep

    function getMonitorForScreen(screen) {
        return monitors.find(m => m.modelData === screen)
    }

    signal monitorBrightnessChanged(var monitor, real newBrightness)

    function getAvailableMethods() {
        const methods = []
        if (root.enableDdcSupport && monitors.some(m => m.isDdc))
            methods.push("ddcutil")
        if (monitors.some(m => !m.isDdc))
            methods.push("internal")
        if (appleDisplayPresent)
            methods.push("apple")
        return methods
    }

    function increaseBrightness() {
        monitors.forEach(m => m.increaseBrightness())
    }

    function decreaseBrightness() {
        monitors.forEach(m => m.decreaseBrightness())
    }

    function setBrightness(value) {
        monitors.forEach(m => m.setBrightnessDebounced(value))
    }

    function normalizeBacklightDevicePath(devicePath) {
        if (devicePath === undefined || devicePath === null)
            return ""
        const normalized = String(devicePath).trim()
        if (normalized === "")
            return ""
        if (normalized.startsWith("/sys/class/backlight/"))
            return normalized
        if (normalized.indexOf("/") === -1)
            return "/sys/class/backlight/" + normalized
        return normalized
    }

    function getBacklightDeviceName(devicePath) {
        const normalized = normalizeBacklightDevicePath(devicePath)
        if (normalized === "")
            return ""
        const parts = normalized.split("/")
        while (parts.length > 0 && parts[parts.length - 1] === "")
            parts.pop()
        return parts.length > 0 ? parts[parts.length - 1] : ""
    }

    function getMappedBacklightDevice(outputName) {
        const normalizedOutput = String(outputName || "").trim()
        if (normalizedOutput === "")
            return ""
        const configured = configFile.adapter.backlightDeviceMappings || []
        for (let i = 0; i < configured.length; i++) {
            const mapping = configured[i]
            if (!mapping || typeof mapping !== "object")
                continue
            if (String(mapping.output || "").trim() === normalizedOutput)
                return normalizeBacklightDevicePath(mapping.device || "")
        }
        return ""
    }

    function setMappedBacklightDevice(outputName, devicePath) {
        const normalizedOutput = String(outputName || "").trim()
        if (normalizedOutput === "")
            return

        const normalizedDevicePath = normalizeBacklightDevicePath(devicePath)
        const mappings = configFile.adapter.backlightDeviceMappings || []
        const nextMappings = []
        let replaced = false

        for (let i = 0; i < mappings.length; i++) {
            const mapping = mappings[i]
            if (!mapping || typeof mapping !== "object")
                continue
            const mappingOutput = String(mapping.output || "").trim()
            const mappingDevice = normalizeBacklightDevicePath(mapping.device || "")
            if (mappingOutput === "" || mappingDevice === "")
                continue
            if (mappingOutput === normalizedOutput) {
                if (!replaced && normalizedDevicePath !== "")
                    nextMappings.push({ output: normalizedOutput, device: normalizedDevicePath })
                replaced = true
            } else {
                nextMappings.push({ output: mappingOutput, device: mappingDevice })
            }
        }

        if (!replaced && normalizedDevicePath !== "")
            nextMappings.push({ output: normalizedOutput, device: normalizedDevicePath })

        configFile.adapter.backlightDeviceMappings = nextMappings
    }

    function scanBacklightDevices() {
        if (!scanBacklightProc.running)
            scanBacklightProc.running = true
    }

    Component.onCompleted: {
        scanBacklightDevices()
        if (root.enableDdcSupport)
            ddcProc.running = true
    }

    onMonitorsChanged: {
        ddcMonitors = []
        scanBacklightDevices()
        if (root.enableDdcSupport)
            ddcProc.running = true
    }

    Variants {
        id: variants
        model: Quickshell.screens
        Monitor {}
    }

    // Check for Apple Display support (`asdbctl`) - a no-op fallback
    // command if the tool isn't installed, never errors.
    Process {
        running: true
        command: ["sh", "-c", "which asdbctl >/dev/null 2>&1 && asdbctl get || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    // Detect available internal backlight devices under /sys/class/backlight.
    Process {
        id: scanBacklightProc
        command: ["sh", "-c", "for dev in /sys/class/backlight/*; do if [ -f \"$dev/brightness\" ] && [ -f \"$dev/max_brightness\" ]; then echo \"$dev\"; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const data = text.trim()
                if (data === "") {
                    root.availableBacklightDevices = []
                    return
                }
                const lines = data.split("\n")
                const found = []
                const seen = ({})
                for (let i = 0; i < lines.length; i++) {
                    const path = root.normalizeBacklightDevicePath(lines[i])
                    if (path === "" || seen[path])
                        continue
                    seen[path] = true
                    found.push(path)
                }
                root.availableBacklightDevices = found
            }
        }
    }

    // Detect DDC-capable external monitors via `ddcutil detect` - a no-op
    // (empty output) if `ddcutil` isn't installed, since the command
    // itself simply never fires `onExited` in that case (a Quickshell
    // Process behavior confirmed elsewhere in this port - see
    // ClipboardHistoryService's ROADMAP entry) rather than erroring.
    Process {
        id: ddcProc
        property list<var> ddcMonitors: []
        command: ["ddcutil", "detect", "--enable-dynamic-sleep", "--sleep-multiplier=0.5"]
        stdout: StdioCollector {
            onStreamFinished: {
                const displays = text.trim().split("\n\n")
                ddcProc.ddcMonitors = displays.map(d => {
                    const ddcModelMatch = d.match(/(This monitor does not support DDC\/CI|Invalid display)/)
                    const modelMatch = d.match(/Model:\s*(.*)/)
                    const busMatch = d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)
                    const connectorMatch = d.match(/DRM[_ ]connector:\s*card\d+-(.+)/)
                    const ddcModel = ddcModelMatch ? ddcModelMatch.length > 0 : false
                    const model = modelMatch ? modelMatch[1] : "Unknown"
                    const bus = busMatch ? busMatch[1] : "Unknown"
                    const connector = connectorMatch ? connectorMatch[1].trim() : ""
                    return { model: model, busNum: bus, connector: connector, isDdc: !ddcModel }
                })
                root.ddcMonitors = ddcProc.ddcMonitors.filter(m => m.isDdc)
            }
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property bool isDdc: root.enableDdcSupport && root.ddcMonitors.some(m => m.connector === modelData.name)
        readonly property string busNum: root.ddcMonitors.find(m => m.connector === modelData.name)?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        readonly property string method: isAppleDisplay ? "apple" : (isDdc ? "ddcutil" : "internal")

        readonly property bool brightnessControlAvailable: {
            if (isAppleDisplay)
                return true
            if (isDdc)
                return true
            return brightnessPath !== ""
        }

        property real brightness
        property real queuedBrightness: NaN
        property bool commandRunning: false

        property string backlightDevice: ""
        property string brightnessPath: ""
        property string maxBrightnessPath: ""
        property int maxBrightness: 100
        property bool initInProgress: false

        signal brightnessUpdated(real newBrightness)

        readonly property Process refreshProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const dataText = text.trim()
                    if (dataText === "")
                        return

                    let newBrightness = NaN

                    if (monitor.isAppleDisplay) {
                        const val = parseInt(dataText)
                        if (!isNaN(val))
                            newBrightness = val / 101
                    } else if (monitor.isDdc) {
                        const parts = dataText.split(" ")
                        if (parts.length >= 4) {
                            const current = parseInt(parts[3])
                            const max = parseInt(parts[4])
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max
                                newBrightness = current / max
                            }
                        }
                    } else {
                        const lines = dataText.split("\n")
                        if (lines.length >= 2) {
                            const current = parseInt(lines[0].trim())
                            const max = parseInt(lines[1].trim())
                            if (!isNaN(current) && !isNaN(max) && max > 0)
                                newBrightness = current / max
                        }
                    }

                    if (!isNaN(newBrightness) && (Math.abs(newBrightness - monitor.brightness) > 0.001 || monitor.brightness === 0)) {
                        monitor.brightness = newBrightness
                        monitor.brightnessUpdated(monitor.brightness)
                        root.monitorBrightnessChanged(monitor, monitor.brightness)
                    }
                }
            }
        }

        readonly property Process setBrightnessProc: Process {
            stdout: StdioCollector {}
            onExited: (exitCode, exitStatus) => {
                monitor.commandRunning = false
                if (!isNaN(monitor.queuedBrightness)) {
                    Qt.callLater(() => {
                        monitor.setBrightness(monitor.queuedBrightness)
                        monitor.queuedBrightness = NaN
                    })
                }
            }
        }

        function refreshBrightnessFromSystem() {
            if (!monitor.isDdc && !monitor.isAppleDisplay) {
                refreshProc.command = ["sh", "-c", "cat " + monitor.brightnessPath + " && cat " + monitor.maxBrightnessPath]
                refreshProc.running = true
            } else if (monitor.isDdc && monitor.busNum !== "") {
                refreshProc.command = ["ddcutil", "-b", monitor.busNum, "--enable-dynamic-sleep", "--sleep-multiplier=0.05", "getvcp", "10", "--brief"]
                refreshProc.running = true
            } else if (monitor.isAppleDisplay) {
                refreshProc.command = ["asdbctl", "get"]
                refreshProc.running = true
            }
        }

        readonly property FileView brightnessWatcher: FileView {
            path: (!monitor.isDdc && !monitor.isAppleDisplay && monitor.brightnessPath !== "") ? monitor.brightnessPath : ""
            watchChanges: path !== ""
            onFileChanged: Qt.callLater(() => monitor.refreshBrightnessFromSystem())
        }

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const dataText = text.trim()
                    if (dataText === "")
                        return

                    if (monitor.isAppleDisplay) {
                        const val = parseInt(dataText)
                        if (!isNaN(val))
                            monitor.brightness = val / 101
                    } else if (monitor.isDdc) {
                        const parts = dataText.split(" ")
                        if (parts.length >= 4) {
                            const current = parseInt(parts[3])
                            const max = parseInt(parts[4])
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max
                                monitor.brightness = current / max
                            }
                        }
                    } else {
                        const lines = dataText.split("\n")
                        if (lines.length >= 3) {
                            monitor.backlightDevice = lines[0]
                            monitor.brightnessPath = monitor.backlightDevice + "/brightness"
                            monitor.maxBrightnessPath = monitor.backlightDevice + "/max_brightness"

                            const current = parseInt(lines[1])
                            const max = parseInt(lines[2])
                            if (!isNaN(current) && !isNaN(max) && max > 0) {
                                monitor.maxBrightness = max
                                monitor.brightness = current / max
                            }
                        } else {
                            monitor.backlightDevice = ""
                            monitor.brightnessPath = ""
                            monitor.maxBrightnessPath = ""
                        }
                    }

                    monitor.initInProgress = false
                }
            }
            onExited: (exitCode, exitStatus) => { monitor.initInProgress = false }
        }

        readonly property real stepSize: root.brightnessStep / 100.0

        readonly property Timer timer: Timer {
            interval: monitor.isDdc ? 250 : 33
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness)
                    monitor.queuedBrightness = NaN
                }
            }
        }

        function setBrightnessDebounced(value) {
            monitor.queuedBrightness = value
            timer.start()
        }

        function increaseBrightness() {
            const value = !isNaN(monitor.queuedBrightness) ? monitor.queuedBrightness : monitor.brightness
            setBrightnessDebounced(value + stepSize)
        }

        function decreaseBrightness() {
            const value = !isNaN(monitor.queuedBrightness) ? monitor.queuedBrightness : monitor.brightness
            setBrightnessDebounced(value - stepSize)
        }

        function setBrightness(value) {
            const min = root.enforceMinimum && isDdc ? 0.01 : 0
            value = Math.max(min, Math.min(1, value))
            const rounded = Math.round(value * 100)

            monitor.brightness = value
            monitor.brightnessUpdated(value)
            root.monitorBrightnessChanged(monitor, monitor.brightness)

            if (timer.running || monitor.commandRunning) {
                monitor.queuedBrightness = value
                return
            }

            if (isAppleDisplay) {
                monitor.commandRunning = true
                setBrightnessProc.command = ["asdbctl", "set", rounded]
                setBrightnessProc.running = true
            } else if (isDdc && busNum !== "") {
                monitor.commandRunning = true
                const ddcValue = Math.round(value * monitor.maxBrightness)
                const ddcBus = busNum
                Qt.callLater(() => {
                    setBrightnessProc.command = ["ddcutil", "-b", ddcBus, "--noverify", "--async", "--enable-dynamic-sleep", "--sleep-multiplier=0.05", "setvcp", "10", ddcValue]
                    setBrightnessProc.running = true
                })
            } else if (!isDdc) {
                monitor.commandRunning = true
                const setMin = root.enforceMinimum ? "-n" : ""
                const backlightDeviceName = root.getBacklightDeviceName(monitor.backlightDevice)
                if (backlightDeviceName !== "")
                    setBrightnessProc.command = ["brightnessctl", "-d", backlightDeviceName, "s", rounded + "%", setMin]
                else
                    setBrightnessProc.command = ["brightnessctl", "s", rounded + "%", setMin]
                setBrightnessProc.running = true
            }
        }

        function initBrightness() {
            monitor.initInProgress = true
            if (isAppleDisplay) {
                initProc.command = ["asdbctl", "get"]
                initProc.running = true
            } else if (isDdc && busNum !== "") {
                initProc.command = ["ddcutil", "-b", busNum, "--enable-dynamic-sleep", "--sleep-multiplier=0.05", "getvcp", "10", "--brief"]
                initProc.running = true
            } else if (!isDdc) {
                const preferredDevicePath = root.getMappedBacklightDevice(modelData.name)
                const probeScript = ["preferred=\"$1\"", "if [ -n \"$preferred\" ] && [ ! -d \"$preferred\" ]; then preferred=\"/sys/class/backlight/$preferred\"; fi", "selected=\"\"",
                    "if [ -n \"$preferred\" ] && [ -f \"$preferred/brightness\" ] && [ -f \"$preferred/max_brightness\" ]; then selected=\"$preferred\"; else for dev in /sys/class/backlight/*; do if [ -f \"$dev/brightness\" ] && [ -f \"$dev/max_brightness\" ]; then selected=\"$dev\"; break; fi; done; fi",
                    "if [ -n \"$selected\" ]; then echo \"$selected\"; cat \"$selected/brightness\"; cat \"$selected/max_brightness\"; fi"].join("; ")
                initProc.command = ["sh", "-c", probeScript, "sh", preferredDevicePath]
                initProc.running = true
            } else {
                monitor.initInProgress = false
            }
        }

        onBusNumChanged: initBrightness()
        onIsDdcChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
