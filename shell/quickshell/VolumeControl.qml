import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    property color textColor: "white"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    visible: root.sink && root.sink.ready
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    Row {
        id: rowLayout
        spacing: 4

        NText {
            text: (root.sink && root.sink.ready && root.sink.audio.muted) ? "󰖁" : ""
            color: root.textColor
            pointSize: Style.fontSizeL
        }

        NText {
            text: (root.sink && root.sink.ready) ? (root.sink.audio.muted ? "muted" : Math.round(root.sink.audio.volume * 100) + "%") : ""
            color: root.textColor
            pointSize: Style.fontSizeL
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.sink || !root.sink.ready)
                return

            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["pavucontrol"])
            else if (mouse.button === Qt.RightButton)
                root.sink.audio.muted = !root.sink.audio.muted
        }
    }
}
