import QtQuick
import Quickshell
import Quickshell.Widgets

// Themed confirmation dialog for pinning/unpinning an app to the dock,
// opened via PinDialogState.open() from either Launcher.qml (right-click a
// result) or DockIcons.qml (right-click an existing dock icon) - one shared
// dialog rather than two different inline popups. windowrule=float +
// center,title:^Pin to Dock$ in zaris.conf places it like the launcher/
// settings/OSD windows - same mechanism, nothing new needed WM-side.
FloatingWindow {
    id: dialog

    visible: PinDialogState.visible
    title: "Pin to Dock"

    implicitWidth: 300
    implicitHeight: 150

    readonly property bool pinned: DockConfig.isPinned(PinDialogState.appId)

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Colors.bg
        border.color: Colors.purple
        border.width: 1

        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 20

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                IconImage {
                    visible: PinDialogState.appIcon !== ""
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    source: PinDialogState.appIcon !== "" ? Quickshell.iconPath(PinDialogState.appIcon, true) : ""
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: PinDialogState.appName
                    color: Colors.text
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    width: actionLabel.implicitWidth + 24
                    height: 32
                    radius: 6
                    color: Colors.pillActive

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: dialog.pinned ? "Remove from Dock" : "Pin to Dock"
                        color: Colors.text
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            DockConfig.togglePin(PinDialogState.appId)
                            PinDialogState.visible = false
                        }
                    }
                }

                Rectangle {
                    width: cancelLabel.implicitWidth + 24
                    height: 32
                    radius: 6
                    color: Colors.pill

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Colors.textMuted
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: PinDialogState.visible = false
                    }
                }
            }
        }
    }
}
