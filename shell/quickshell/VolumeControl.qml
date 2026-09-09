import QtQuick
import Quickshell.Services.Pipewire

// Bar icon showing only mute state (matching Noctalia's own bar - a bare
// speaker/muted-speaker icon, no percentage). Left-click opens
// AudioMixerPanel.qml, a small popup with Output/Input sliders, per-app
// volume, and output/input device selection (the same AudioMixer.qml
// content Settings' own Audio tab shows) - this used to launch `pavucontrol`
// directly; ControlCenter.qml's own audio section (Output/Input sliders
// only, no device list or per-app mixing) still exists separately and is
// unaffected by this change. Right-click still just toggles mute, unchanged.
// Deliberately not gated by ModulesConfig's "volume" tray flag in Bar.qml -
// same reasoning as ControlCenter.qml's media card: Noctalia's own
// reference bar keeps a volume icon visible at the same time its Control
// Center has the richer audio section, so this stays bar-visible
// unconditionally rather than disappearing once "volume" is tray-enabled.
Item {
    id: root

    property color textColor: "white"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    visible: root.sink && root.sink.ready
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    NText {
        id: icon
        text: (root.sink && root.sink.ready && root.sink.audio.muted) ? "󰖁" : ""
        color: root.textColor
        pointSize: Style.fontSizeL
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.sink || !root.sink.ready)
                return

            if (mouse.button === Qt.LeftButton) {
                AudioMixerPanelState.anchorItem = root
                AudioMixerPanelState.visible = !AudioMixerPanelState.visible
            } else if (mouse.button === Qt.RightButton)
                root.sink.audio.muted = !root.sink.audio.muted
        }
    }
}
