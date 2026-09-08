pragma Singleton
import QtQuick

// Shared night-light flag, mirroring StayAwakeState.qml: redshift's
// color-temperature override is applied via X11 RandR gamma ramps, which
// are global to the X server (not per-monitor), and Bar.qml creates one
// NightLight instance per monitor - without a shared singleton each bar's
// icon would show its own independent, and quickly inconsistent, view of a
// single shared toggle.
QtObject {
    property bool active: false
}
