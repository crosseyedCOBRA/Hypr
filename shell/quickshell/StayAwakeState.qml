pragma Singleton
import QtQuick

// Shared "stay awake" flag. xset's screensaver/DPMS state is global to the X
// server (not per-monitor), and Bar.qml creates one StayAwake instance per
// monitor - without a shared singleton each bar's icon would show its own
// independent, and quickly inconsistent, view of a single shared toggle.
QtObject {
    property bool awake: false
}
