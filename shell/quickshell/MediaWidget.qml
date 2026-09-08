import QtQuick
import Quickshell

// MPRIS "now playing" bar widget - a play/pause icon (showing the action a
// click will perform, not the current state) plus a truncated "artist -
// title", built directly on MediaService.qml. Hidden entirely when no
// controllable player exists (matching KernelVersion.qml's pattern of
// vanishing rather than showing an empty state), so it costs no bar space
// when nothing's playing.
Item {
    id: root

    property color textColor: "white"
    property color activeColor: "white"
    readonly property int maxTitleWidth: 160

    visible: !!MediaService.currentPlayer
    implicitWidth: visible ? rowLayout.implicitWidth : 0
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 6

        NText {
            text: MediaService.isPlaying ? "" : ""
            color: MediaService.isPlaying ? root.activeColor : root.textColor
            pointSize: Style.fontSizeL
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                onClicked: MediaService.playPause()
            }
        }

        NText {
            text: {
                const title = MediaService.trackTitle
                const artist = MediaService.trackArtist
                return artist ? (artist + " - " + title) : title
            }
            color: root.textColor
            pointSize: Style.fontSizeL
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.maxTitleWidth)
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        MediaService.playPause()
                    else if (mouse.button === Qt.RightButton)
                        MediaService.next()
                }
            }
        }
    }
}
