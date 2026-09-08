import QtQuick
import Quickshell
import Quickshell.Widgets

// Themed confirmation dialog for pinning/unpinning an app to the dock,
// opened via PinDialogState.open() from either Launcher.qml (right-click a
// result) or DockIcons.qml (right-click an existing dock icon) - one shared
// dialog rather than two different inline popups. windowrule=float +
// center,title:^Pin to Dock$ in zaris.conf places it like the launcher/
// settings/OSD windows - same mechanism, nothing new needed WM-side.
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): the two hand-rolled
// "button" Rectangle+Text+MouseArea groups are now NButton (real hover
// states, matches the styling every other ported button in this shell
// uses) - the outer dialog chrome (bordered Rectangle) and the IconImage
// row are left as-is, no ported widget maps onto either more usefully than
// what's already there.
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

                NText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: PinDialogState.appName
                    color: Colors.text
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightBold
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                NButton {
                    text: dialog.pinned ? "Remove from Dock" : "Pin to Dock"
                    backgroundColor: Colors.pillActive
                    textColor: Colors.text
                    onClicked: {
                        DockConfig.togglePin(PinDialogState.appId)
                        PinDialogState.visible = false
                    }
                }

                NButton {
                    text: "Cancel"
                    outlined: true
                    backgroundColor: Colors.textMuted
                    onClicked: PinDialogState.visible = false
                }
            }
        }
    }
}
