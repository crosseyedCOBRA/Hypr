import QtQuick
import Quickshell.Services.Pipewire

// Shared Volumes/Devices audio mixer content - embedded both in
// AudioMixerPanel.qml (the bar's volume-icon-anchored popup) and Settings'
// own Audio tab, same "one component, two embeddings" approach
// CalendarWidget.qml already established (which is what to follow for the
// exact `width`-comes-from-the-caller contract - this Column doesn't bind
// its own width, every embedder sets it explicitly).
//
// Real-device vs. stream-node filtering below was verified empirically in
// a live sandbox (a throwaway `qs -p` script dumping Pipewire.nodes) rather
// than guessed from Quickshell's own qmltypes, which documents `type` only
// as an opaque PwNodeType::Flags bitmask with no worked example. Confirmed
// live: a real audio output device (this machine's HyperX headset) reads
// isSink=true isStream=false type=17; its own mic reads isSink=false
// isStream=false type=9; a genuine playback stream (paplay, captured mid-
// playback) reads isSink=true isStream=true type=21. type&1 isolates the
// "Audio" bit shared by all three (excluding this machine's own non-audio
// Pipewire nodes - Dummy-Driver/Freewheel-Driver/Midi-Bridge/
// bluez_midi.server, all type=0) - isSink/isStream alone already
// distinguish device vs. stream without needing the bitmask at all, type&1
// is only there to exclude non-audio nodes from the device lists.
Column {
    id: root

    spacing: 14

    property int activeTab: 0 // 0 = Volumes, 1 = Devices

    readonly property PwNode pwSink: Pipewire.defaultAudioSink
    readonly property PwNode pwSource: Pipewire.defaultAudioSource

    readonly property var outputDevices: Pipewire.nodes.values.filter(function (n) { return n.isSink && !n.isStream && (n.type & 1) !== 0 })
    readonly property var inputDevices: Pipewire.nodes.values.filter(function (n) { return !n.isSink && !n.isStream && (n.type & 1) !== 0 })
    // Playback streams only (an app sending audio out) - pavucontrol's
    // "Recording" tab equivalent (apps capturing audio, e.g. OBS) isn't
    // covered here, matching the reference screenshot's own "Volumes"
    // sub-tab, which only shows output-side app streams.
    readonly property var playbackStreams: Pipewire.nodes.values.filter(function (n) { return n.isSink && n.isStream })

    // Keeps every node (not just the two defaults, unlike ControlCenter.qml's
    // own narrower tracker) alive/reactive for as long as this component
    // exists - needed for the Devices list and the per-app stream rows,
    // neither of which existed before this component.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    NTabBar {
        width: root.width
        tabHeight: 26

        NTabButton {
            text: "Volumes"
            checked: root.activeTab === 0
            onClicked: root.activeTab = 0
        }

        NTabButton {
            text: "Devices"
            checked: root.activeTab === 1
            onClicked: root.activeTab = 1
        }
    }

    // ==================== Volumes ====================
    Column {
        width: root.width
        spacing: 14
        visible: root.activeTab === 0

        Column {
            width: parent.width
            spacing: 4
            visible: !!root.pwSink && root.pwSink.ready

            Row {
                width: parent.width
                spacing: 6

                NIconButton {
                    baseSize: 22
                    icon: (root.pwSink && root.pwSink.ready && root.pwSink.audio.muted) ? "󰖁" : ""
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (root.pwSink)
                            root.pwSink.audio.muted = !root.pwSink.audio.muted
                    }
                }

                NText {
                    text: "Output - " + (root.pwSink && root.pwSink.ready ? root.pwSink.description : "")
                    width: parent.width - 22 - parent.spacing
                    elide: Text.ElideRight
                    color: Colors.textMuted
                    pointSize: Style.fontSizeXS
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            NSlider {
                width: parent.width
                from: 0
                to: 1.0
                value: root.pwSink && root.pwSink.ready ? root.pwSink.audio.volume : 0
                onMoved: {
                    if (root.pwSink)
                        root.pwSink.audio.volume = value
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            visible: !!root.pwSource && root.pwSource.ready

            Row {
                width: parent.width
                spacing: 6

                NIconButton {
                    baseSize: 22
                    icon: (root.pwSource && root.pwSource.ready && root.pwSource.audio.muted) ? "" : ""
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        if (root.pwSource)
                            root.pwSource.audio.muted = !root.pwSource.audio.muted
                    }
                }

                NText {
                    text: "Input - " + (root.pwSource && root.pwSource.ready ? root.pwSource.description : "")
                    width: parent.width - 22 - parent.spacing
                    elide: Text.ElideRight
                    color: Colors.textMuted
                    pointSize: Style.fontSizeXS
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            NSlider {
                width: parent.width
                from: 0
                to: 1.0
                value: root.pwSource && root.pwSource.ready ? root.pwSource.audio.volume : 0
                onMoved: {
                    if (root.pwSource)
                        root.pwSource.audio.volume = value
                }
            }
        }

        NText {
            text: "Applications"
            visible: root.playbackStreams.length > 0
            color: Colors.text
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            topPadding: 4
        }

        Repeater {
            model: root.playbackStreams

            Column {
                id: streamRow
                required property var modelData
                width: root.width
                spacing: 4

                Row {
                    width: parent.width
                    spacing: 6

                    NIconButton {
                        baseSize: 22
                        icon: streamRow.modelData.audio.muted ? "󰖁" : ""
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                    }

                    NText {
                        text: streamRow.modelData.description || streamRow.modelData.name
                        width: parent.width - 22 - parent.spacing
                        elide: Text.ElideRight
                        color: Colors.textMuted
                        pointSize: Style.fontSizeXS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                NSlider {
                    width: parent.width
                    from: 0
                    to: 1.0
                    value: streamRow.modelData.audio.volume
                    onMoved: streamRow.modelData.audio.volume = value
                }
            }
        }
    }

    // ==================== Devices ====================
    Column {
        width: root.width
        spacing: 10
        visible: root.activeTab === 1

        NText {
            text: "Output device"
            color: Colors.text
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
        }

        NText {
            visible: root.outputDevices.length === 0
            text: "No output devices found."
            color: Colors.textMuted
            pointSize: Style.fontSizeXS
        }

        Repeater {
            model: root.outputDevices

            NRadioButton {
                required property var modelData
                width: root.width
                text: modelData.description || modelData.name
                pointSize: Style.fontSizeS
                autoExclusive: false
                checked: Pipewire.defaultAudioSink === modelData
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        NText {
            text: "Input device"
            color: Colors.text
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            topPadding: 8
        }

        NText {
            visible: root.inputDevices.length === 0
            text: "No input devices found."
            color: Colors.textMuted
            pointSize: Style.fontSizeXS
        }

        Repeater {
            model: root.inputDevices

            NRadioButton {
                required property var modelData
                width: root.width
                text: modelData.description || modelData.name
                pointSize: Style.fontSizeS
                autoExclusive: false
                checked: Pipewire.defaultAudioSource === modelData
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }
}
