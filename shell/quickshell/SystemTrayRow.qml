import QtQuick
import Quickshell.Services.SystemTray

// Modern StatusNotifierItem-based tray (DBus), not the XEmbed protocol our
// own WM used to host for the old built-in bar - this is the least-verified
// widget in the bar; the exact item API is the most likely thing to need a
// small fix once this is actually running.
Row {
    id: root

    // The hosting PanelWindow, passed in from Bar.qml - StatusNotifierItem's
    // display() needs it to know which window to anchor its native context
    // menu (Steam/Vesktop/etc.'s own "Quit", "Settings", ... options) to.
    required property var window

    spacing: 6

    Repeater {
        model: SystemTray.items

        Image {
            id: trayIcon
            required property var modelData

            source: modelData.icon
            sourceSize.width: 18
            sourceSize.height: 18
            width: 18
            height: 18

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayIcon.modelData.activate()
                    } else if (trayIcon.modelData.hasMenu) {
                        const pos = trayIcon.mapToItem(null, 0, trayIcon.height)
                        trayIcon.modelData.display(root.window, pos.x, pos.y)
                    } else {
                        trayIcon.modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
