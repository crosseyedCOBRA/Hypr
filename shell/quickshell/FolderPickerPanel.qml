import QtQuick
import Quickshell

// Folder picker - directory navigation (Up + click-to-enter subfolders),
// not a flat thumbnail grid like IconPickerPanel.qml/WallpaperPickerPanel.qml,
// since picking a folder is a genuinely different task from picking a
// file. See FolderPickerPanelState.qml's own header comment for the
// callback-based open() this is built around.
FloatingWindow {
    id: panel

    visible: FolderPickerPanelState.visible
    title: "Choose Folder"

    implicitWidth: 440
    implicitHeight: 440

    // Restores Settings' own visibility (hidden for the duration by
    // FolderPickerPanelState.open() - see its own comment for why)
    // whenever this panel actually closes, regardless of path - Select
    // This Folder, the Cancel button below, or anything else that flips
    // FolderPickerPanelState.visible false.
    onVisibleChanged: {
        if (!panel.visible)
            FolderPickerPanelState.restoreSettings()
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

                NIconButton {
                    id: upButton
                    anchors.verticalCenter: parent.verticalCenter
                    baseSize: 20
                    icon: ""
                    tooltipText: "Up one level"
                    enabled: FolderPickerPanelState.directory !== "/"
                    onClicked: FolderPickerPanelState.navigateUp()
                }

                NText {
                    // Extra room reserved on the right for the Cancel
                    // button now sharing this row.
                    width: parent.width - upButton.width - cancelButton.width - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: FolderPickerPanelState.directory
                    color: Colors.text
                    pointSize: Style.fontSizeS
                    elide: Text.ElideMiddle
                }

                NIconButton {
                    id: cancelButton
                    anchors.verticalCenter: parent.verticalCenter
                    baseSize: 20
                    icon: ""
                    tooltipText: "Cancel"
                    onClicked: FolderPickerPanelState.visible = false
                }
            }

            NText {
                visible: !FolderPickerPanelState.scanning && FolderPickerPanelState.subdirs.length === 0
                text: "No subfolders here"
                color: Colors.textMuted
                pointSize: Style.fontSizeM
            }

            NListView {
                id: list
                width: parent.width
                height: parent.height - y - selectButton.height - parent.spacing
                model: FolderPickerPanelState.subdirs

                delegate: Rectangle {
                    width: list.width
                    height: 36
                    radius: Style.radiusS
                    color: rowArea.containsMouse ? Colors.pillActive : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        NIcon {
                            icon: ""
                            color: Colors.blue
                            pointSize: Style.fontSizeM
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        NText {
                            text: modelData
                            color: Colors.text
                            pointSize: Style.fontSizeM
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: FolderPickerPanelState.navigateInto(modelData)
                    }
                }
            }

            NButton {
                id: selectButton
                text: "Select This Folder"
                fontSize: Style.fontSizeS
                backgroundColor: Colors.pillActive
                textColor: Colors.text
                onClicked: FolderPickerPanelState.selectCurrent()
            }
        }
    }
}
