import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history picker - a genuinely new UI, not ported from anywhere
// (Noctalia's own picker wasn't examined; this follows Launcher.qml's own
// established search+list pattern instead, for consistency with the rest
// of this shell rather than introducing a second, differently-styled
// picker convention). Left-click copies an entry back to the clipboard and
// closes the panel; right-click removes just that entry; Escape closes.
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): the "Clear" button
// is now NButton, the plain ListView is now NListView (real scrollbar
// styling + edge-fade gradient masks), and every raw Text is now NText.
// The search field's bordered-Rectangle+TextInput is deliberately left
// as-is rather than switched to NTextInput - its custom Up/Down/Return/
// Escape key handling (result-list navigation) needs `Keys.onXxx` attached
// handlers declared directly inside the TextField itself, which isn't
// something an external alias reference into NTextInput's own internal
// TextField can cleanly carry, so this stays a custom field rather than
// fighting the ported widget's shape for a feature it doesn't expose.
FloatingWindow {
    id: panel

    visible: ClipboardHistoryPanelState.visible
    title: "Clipboard History"

    implicitWidth: 480
    implicitHeight: 420

    IpcHandler {
        target: "clipboard"

        function toggle(): void { ClipboardHistoryPanelState.visible = !ClipboardHistoryPanelState.visible }
        function show(): void { ClipboardHistoryPanelState.visible = true }
        function hide(): void { ClipboardHistoryPanelState.visible = false }
    }

    property string query: ""

    property var filteredItems: {
        const q = query.toLowerCase().trim()
        const all = ClipboardHistoryService.items
        return q === "" ? all : all.filter(function (item) {
            return item.preview.toLowerCase().includes(q)
        })
    }

    function glyphFor(contentType) {
        switch (contentType) {
        case "link": return ""
        case "file": return ""
        case "code": return ""
        case "color": return ""
        default: return ""
        }
    }

    onVisibleChanged: {
        if (visible) {
            query = ""
            resultList.currentIndex = 0
            searchField.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: parent.width - clearAllButton.width - parent.spacing
                    height: 36
                    radius: 6
                    color: "transparent"
                    border.color: Colors.textMuted
                    border.width: 1

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Colors.text
                        font.pixelSize: 16
                        clip: true
                        focus: true
                        text: panel.query

                        onTextChanged: panel.query = text

                        Keys.onEscapePressed: ClipboardHistoryPanelState.visible = false
                        Keys.onReturnPressed: {
                            if (resultList.currentModelData)
                                ClipboardHistoryService.copyToClipboard(resultList.currentModelData.id)
                            ClipboardHistoryPanelState.visible = false
                        }
                        Keys.onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, resultList.count - 1)
                        Keys.onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
                    }
                }

                NButton {
                    id: clearAllButton
                    text: "Clear"
                    fontSize: Style.fontSizeS
                    backgroundColor: Colors.pill
                    textColor: Colors.coral
                    onClicked: ClipboardHistoryService.wipeAll()
                }
            }

            NText {
                visible: !ClipboardHistoryService.clipnotifyAvailable
                width: parent.width
                wrapMode: Text.WordWrap
                text: "clipnotify isn't installed - clipboard history won't capture anything new until it is."
                color: Colors.coral
                pointSize: Style.fontSizeXS
            }

            NListView {
                id: resultList
                width: parent.width
                height: parent.height - searchField.height - parent.spacing - (ClipboardHistoryService.clipnotifyAvailable ? 0 : 20)
                model: panel.filteredItems
                currentIndex: 0

                property var currentModelData: count > 0 ? model[currentIndex] : null

                NText {
                    visible: resultList.count === 0
                    anchors.centerIn: parent
                    text: "No clipboard history yet"
                    color: Colors.textMuted
                    pointSize: Style.fontSizeM
                }

                delegate: Rectangle {
                    width: resultList.width
                    height: 44
                    radius: 6
                    color: ListView.isCurrentItem ? Colors.pillActive : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        NText {
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.glyphFor(modelData.contentType)
                            color: Colors.blue
                            pointSize: Style.fontSizeM
                            horizontalAlignment: Text.AlignHCenter
                        }

                        NText {
                            width: parent.width - 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.preview
                            color: Colors.text
                            pointSize: Style.fontSizeM
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                ClipboardHistoryService.deleteById(modelData.id)
                                return
                            }
                            ClipboardHistoryService.copyToClipboard(modelData.id)
                            ClipboardHistoryPanelState.visible = false
                        }
                    }
                }
            }
        }
    }
}
