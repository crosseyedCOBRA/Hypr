import QtQuick
import Quickshell
import Quickshell.Io

// Transient volume/brightness popup. Shown by OSDState.show(), which is
// driven externally over IPC by the keybinds in zaris.conf:
//   qs ipc call osd volume <0-100> <true|false muted>
//   qs ipc call osd brightness <0-100>
// windowrule=float + windowrule=center,title:^OSD$ in zaris.conf places it
// like the launcher/settings windows - same mechanism, nothing new needed
// on the WM side for this one.
FloatingWindow {
    id: osdWindow

    visible: OSDState.visible
    title: "OSD"

    implicitWidth: 260
    implicitHeight: 90

    IpcHandler {
        target: "osd"

        function volume(percent: string, muted: string): void {
            OSDState.show("volume", parseInt(percent), muted === "true")
        }

        function brightness(percent: string): void {
            OSDState.show("brightness", parseInt(percent), false)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Colors.bg
        border.color: OSDState.kind === "brightness" ? Colors.blue : Colors.teal
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (OSDState.kind === "brightness")
                        return " " + Math.round(OSDState.level * 100) + "%"
                    if (OSDState.muted)
                        return " muted"
                    return " " + Math.round(OSDState.level * 100) + "%"
                }
                color: Colors.text
                font.pixelSize: 16
            }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Colors.pill

                Rectangle {
                    width: parent.width * (OSDState.muted ? 0 : OSDState.level)
                    height: parent.height
                    radius: 4
                    color: OSDState.kind === "brightness" ? Colors.blue : Colors.teal
                }
            }
        }
    }
}
