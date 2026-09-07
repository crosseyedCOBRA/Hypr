pragma Singleton
import QtQuick

// Shared open/closed state for the "hidden tray" flyout (Overflow.qml),
// plus which monitor's chevron opened it - so the flyout shows only the
// tray modules configured for that specific screen.
QtObject {
    property bool visible: false
    property var panel: null
}
