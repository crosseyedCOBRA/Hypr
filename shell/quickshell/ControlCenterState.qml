pragma Singleton
import QtQuick

// Shared open/closed state for the Control Center flyout (ControlCenter.qml),
// plus which monitor's chevron opened it - so the panel shows only the
// tray modules configured for that specific screen.
QtObject {
    property bool visible: false
    property var panel: null
}
