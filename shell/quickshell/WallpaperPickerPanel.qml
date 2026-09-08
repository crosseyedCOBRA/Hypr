import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper picker - a genuinely new UI (not ported from anywhere, same
// reasoning as ClipboardHistoryPanel.qml: Noctalia's own picker wasn't
// examined given WallpaperService.qml itself wasn't a straight port).
// Click a thumbnail to set it as the wallpaper and close; the currently
// active wallpaper gets a highlighted border.
FloatingWindow {
    id: panel

    visible: WallpaperPickerPanelState.visible
    title: "Wallpaper Picker"

    implicitWidth: 560
    implicitHeight: 460

    IpcHandler {
        target: "wallpaper"

        function toggle(): void { WallpaperPickerPanelState.visible = !WallpaperPickerPanelState.visible }
        function show(): void { WallpaperPickerPanelState.visible = true }
        function hide(): void { WallpaperPickerPanelState.visible = false }
    }

    property string directoryInput: WallpaperService.directory

    onVisibleChanged: {
        if (visible) {
            directoryInput = WallpaperService.directory
            WallpaperService.scan()
        }
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
                        Keys.onReturnPressed: WallpaperService.setDirectory(panel.directoryInput)
                    }
                }

                Rectangle {
                    id: rescanButton
                    width: 70
                    height: 32
                    radius: 6
                    color: Colors.pill

                    Text {
                        anchors.centerIn: parent
                        text: "Rescan"
                        color: Colors.text
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: WallpaperService.setDirectory(panel.directoryInput)
                    }
                }
            }

            Row {
                width: parent.width
                height: 28
                spacing: 12

                Text {
                    text: "Rotate"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colors.text
                    font.pixelSize: 13
                }

                ToggleSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: WallpaperService.rotationEnabled
                    onToggled: newChecked => WallpaperService.setRotationEnabled(newChecked)
                }

                Text {
                    visible: WallpaperService.rotationEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    text: "every " + WallpaperService.rotationIntervalMinutes + " min"
                    color: Colors.textMuted
                    font.pixelSize: 12
                }
            }

            Text {
                visible: !WallpaperService.scanning && WallpaperService.images.length === 0
                text: "No images found in this folder"
                color: Colors.textMuted
                font.pixelSize: 13
            }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - y
                clip: true
                cellWidth: 120
                cellHeight: 80
                model: WallpaperService.images

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        color: Colors.pill
                        radius: 6
                        border.color: modelData === WallpaperService.current ? Colors.pillActive : "transparent"
                        border.width: 2
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 240
                            sourceSize.height: 160
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                WallpaperService.setWallpaper(modelData)
                                WallpaperPickerPanelState.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
