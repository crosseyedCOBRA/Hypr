import QtQuick
import Quickshell

// Bar-anchored volume mixer popup - clicking the bar's VolumeControl icon
// opens this instead of launching pavucontrol directly (that left-click
// behavior moved to a right-click-menu-free quick action: the icon's own
// right-click mute toggle is unaffected, see VolumeControl.qml). Same
// PopupWindow-anchored-under-the-clicked-bar-icon treatment as
// NotificationHistoryPanel.qml - see that file's own header comment for why
// that's the established pattern for a popup triggered directly by a bar
// icon (as opposed to Bluetooth/Clipboard/Wallpaper/the avatar picker,
// which open from Control Center tiles instead and stay centered
// FloatingWindows).
//
// Content itself (Volumes/Devices sub-tabs, real Pipewire device/stream
// data) lives in the shared AudioMixer.qml, reused verbatim by Settings'
// own Audio tab - see that file's own header comment for the empirically-
// verified node filtering this is built on.
PopupWindow {
    id: panel

    visible: AudioMixerPanelState.visible && !!AudioMixerPanelState.anchorItem
    color: Colors.bg

    implicitWidth: 360
    implicitHeight: Math.min(mixer.implicitHeight + 96, 560)

    anchor.item: AudioMixerPanelState.anchorItem
    anchor.rect.x: AudioMixerPanelState.anchorItem ? (AudioMixerPanelState.anchorItem.width - implicitWidth) / 2 : 0
    anchor.rect.y: BarConfig.popupAnchorY(AudioMixerPanelState.anchorItem, implicitHeight)

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                width: parent.width
                height: 30

                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    NIcon {
                        icon: ""
                        color: Colors.purple
                        pointSize: Style.fontSizeXL
                    }

                    NText {
                        text: "Audio Mixer"
                        color: Colors.text
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Open Audio settings"
                        onClicked: {
                            SettingsState.requestedCategory = "audio"
                            // Not ControlCenterState.barItem (Settings'
                            // usual anchor, set by Control Center's own
                            // gear button) - confirmed live that it's only
                            // ever assigned lazily, the first time Control
                            // Center's bar launcher icon is clicked
                            // (BarControlCenterLauncher.qml), so it can
                            // still be null here if a user opens this popup
                            // straight from the volume icon without ever
                            // having opened Control Center first - Settings
                            // would then silently fail to show at all
                            // (visible: SettingsState.visible &&
                            // !!SettingsState.targetItem). This popup's own
                            // anchorItem is guaranteed valid at this point
                            // instead (the popup couldn't be open otherwise).
                            SettingsState.targetItem = AudioMixerPanelState.anchorItem
                            SettingsState.visible = true
                            AudioMixerPanelState.visible = false
                        }
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Close"
                        onClicked: AudioMixerPanelState.visible = false
                    }
                }
            }

            NScrollView {
                width: parent.width
                height: parent.height - 42
                clip: true

                AudioMixer {
                    id: mixer
                    width: parent.width
                }
            }
        }
    }
}
