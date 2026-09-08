import QtQuick
import Quickshell

// MPRIS "now playing" bar widget - a play/pause icon (showing the action a
// click will perform, not the current state), a truncated "artist - title",
// and a compact read-only progress scrubber (matching Noctalia's bar-mini
// media widget - a slim position/length indicator, not draggable; seeking
// belongs in a full media panel, which Zaris doesn't have one of yet),
// built directly on MediaService.qml. Hidden entirely when no controllable
// player exists (matching KernelVersion.qml's pattern of vanishing rather
// than showing an empty state), so it costs no bar space when nothing's
// playing.
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

        // Known caveat, not fixable from here: browser/YouTube MPRIS
        // bridges (Firefox's, confirmed live) report no real
        // `mpris:length` at the D-Bus level at all (checked directly via
        // `busctl ... Metadata` - no such key), yet Quickshell's own
        // MprisPlayer.length still returns a nonzero, climbing value for
        // one anyway - some internal fallback/synthesis with no exposed
        // way to distinguish it from a real reported duration. For that
        // class of source this renders as permanently near-full rather
        // than hidden. Real players (mpv, VLC, Spotify, etc.) report
        // `mpris:length` properly per the MPRIS spec and aren't affected -
        // this is a one-player-type gap, not a design flaw in the bar.
        Item {
            width: 32
            height: 4
            visible: MediaService.trackLength > 0
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Colors.pill
            }

            Rectangle {
                width: parent.width * (MediaService.trackLength > 0 ? Math.min(1, MediaService.currentPosition / MediaService.trackLength) : 0)
                height: parent.height
                radius: height / 2
                color: root.activeColor
            }
        }
    }
}
