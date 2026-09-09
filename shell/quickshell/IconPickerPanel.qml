import QtQuick
import Quickshell

// Icon file picker for the Bar tab's Launcher/Control Center icon fields -
// see IconPickerPanelState.qml's own header comment for why this exists
// (a custom in-QML picker, replacing an attempted QtQuick.Dialogs
// FileDialog that turned out to be unclickable under this WM) and why one
// shared panel covers both fields (`target`). Same GridView-thumbnail
// picker shape as WallpaperPickerPanel.qml, scoped to icon files instead
// of wallpapers.
FloatingWindow {
    id: panel

    visible: IconPickerPanelState.visible
    title: "Choose Icon"

    implicitWidth: 480
    implicitHeight: 420

    property string directoryInput: IconPickerPanelState.directory

    onVisibleChanged: {
        if (visible)
            directoryInput = IconPickerPanelState.directory
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width - rescanButton.width - parent.spacing
                    height: 32
                    radius: 6
                    color: "transparent"
                    border.color: Colors.textMuted
                    border.width: 1

                    TextInput {
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Colors.text
                        font.pixelSize: 13
                        clip: true
                        text: panel.directoryInput
                        onTextChanged: panel.directoryInput = text
                        Keys.onReturnPressed: {
                            IconPickerPanelState.directory = panel.directoryInput
                            IconPickerPanelState.scan()
                        }
                    }
                }

                NButton {
                    id: rescanButton
                    text: "Rescan"
                    fontSize: Style.fontSizeS
                    backgroundColor: Colors.pill
                    textColor: Colors.text
                    onClicked: {
                        IconPickerPanelState.directory = panel.directoryInput
                        IconPickerPanelState.scan()
                    }
                }
            }

            NText {
                visible: !IconPickerPanelState.scanning && IconPickerPanelState.images.length === 0
                text: "No icon files found in this folder"
                color: Colors.textMuted
                pointSize: Style.fontSizeM
            }

            NGridView {
                id: grid
                width: parent.width
                height: parent.height - y
                cellWidth: 100
                cellHeight: 100
                model: IconPickerPanelState.images

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        color: Colors.pill
                        radius: Style.radiusS
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 8
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 128
                            sourceSize.height: 128
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: IconPickerPanelState.select(modelData)
                        }
                    }
                }
            }
        }
    }
}
