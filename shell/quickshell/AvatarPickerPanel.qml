import QtQuick
import Quickshell
import Quickshell.Io

// Profile picture picker - opened by clicking the avatar in
// ControlCenter.qml's header. Same directory-browse-thumbnail-grid pattern
// as WallpaperPickerPanel.qml (a genuinely new UI, not ported from
// anywhere - see that file's own header comment for why), scoped down:
// no rotation, no "current" tracking by path (an avatar is just whichever
// file was last copied to `~/.face`, there's nothing meaningful to
// highlight as "active" the way a wallpaper's exact source path is).
// Picking a thumbnail copies that file to `~/.face` (overwriting whatever
// was there) and closes the panel - see AvatarPickerPanelState.qml's own
// comment for why a plain `cp` needs a cache-busting version bump
// alongside it for the change to actually show up live.
FloatingWindow {
    id: panel

    visible: AvatarPickerPanelState.visible
    title: "Choose Profile Picture"

    implicitWidth: 480
    implicitHeight: 420

    IpcHandler {
        target: "avatar"

        function toggle(): void { AvatarPickerPanelState.visible = !AvatarPickerPanelState.visible }
        function show(): void { AvatarPickerPanelState.visible = true }
        function hide(): void { AvatarPickerPanelState.visible = false }
    }

    property string directoryInput: Quickshell.env("HOME") + "/Pictures"
    property var images: []
    property bool scanning: false

    function scan() {
        if (scanning)
            return
        scanning = true
        // Plain argv array, not a `sh -c` string - see WallpaperService
        // .qml's identical scan() for why (nothing to escape regardless of
        // what characters the directory path contains).
        scanProc.command = ["find", panel.directoryInput, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        scanProc.running = true
    }

    // The actual cp-to-~/.face-plus-version-bump mechanism now lives in
    // AvatarPickerPanelState.qml (setAvatar()/setProc there) - shared with
    // Settings.qml's own Profile-tab picture field, so this just delegates
    // instead of keeping its own independent copy of the same Process.
    function setAvatar(path) {
        AvatarPickerPanelState.setAvatar(path)
    }

    onVisibleChanged: {
        if (visible)
            scan()
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                panel.images = this.text.split("\n").filter(function (l) { return l.length > 0 }).sort()
                panel.scanning = false
            }
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
                        Keys.onReturnPressed: panel.scan()
                    }
                }

                NButton {
                    id: rescanButton
                    text: "Rescan"
                    fontSize: Style.fontSizeS
                    backgroundColor: Colors.pill
                    textColor: Colors.text
                    onClicked: panel.scan()
                }
            }

            NText {
                visible: !panel.scanning && panel.images.length === 0
                text: "No images found in this folder"
                color: Colors.textMuted
                pointSize: Style.fontSizeM
            }

            NGridView {
                id: grid
                width: parent.width
                height: parent.height - y
                cellWidth: 100
                cellHeight: 100
                model: panel.images

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
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 200
                            sourceSize.height: 200
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.setAvatar(modelData)
                        }
                    }
                }
            }
        }
    }
}
