pragma Singleton
import QtQuick
import Quickshell.Io

// Shared "do not disturb" flag, mirroring StayAwakeState.qml: dunst's pause
// state is global to the notification daemon (not per-monitor), and
// Bar.qml creates one Dnd instance per monitor - without a shared
// singleton each bar's icon would show its own independent, and quickly
// inconsistent, view of a single shared toggle.
//
// Unlike StayAwakeState (which always starts from a known default X11
// screensaver state), dunst's pause state can persist across shell
// restarts or be changed by something other than this toggle - queried
// once at startup via `dunstctl is-paused` so the icon reflects dunst's
// actual real state rather than assuming "not paused".
QtObject {
    id: root

    property bool paused: false

    Component.onCompleted: queryProc.running = true

    property Process queryProc: Process {
        id: queryProc
        command: ["dunstctl", "is-paused"]
        stdout: StdioCollector {
            onStreamFinished: root.paused = this.text.trim() === "true"
        }
    }
}
