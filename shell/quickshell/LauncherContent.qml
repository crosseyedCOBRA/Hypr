import QtQuick
import Quickshell
import Quickshell.Widgets

// Search field + result list, shared between Launcher.qml's two window
// variants (a centered FloatingWindow in "statusbar" mode, a PopupWindow
// anchored to the bar's taskbar-mode launcher icon in "taskbar" mode -
// see Launcher.qml's own header comment) rather than duplicated between
// them - only ever one of the two is visible at a time, but both need the
// exact same search/list UI.
//
// `launcherRoot` is Launcher.qml's own outer Item, which holds the actual
// query/filteredApps state and the launch()/usage-tracking functions - kept
// there rather than in either window so both variants share one source of
// truth instead of each keeping (and losing, on switching modes) their own
// copy.
Rectangle {
    id: content

    required property var launcherRoot
    // Which of Launcher.qml's two window variants this particular instance
    // lives in is actually showing right now - an Item's own `visible`
    // stays true regardless of its containing window's visibility, so it
    // isn't a usable gate on its own; each window passes in whether
    // BarConfig.layoutMode currently matches it instead.
    required property bool active

    anchors.fill: parent
    color: Colors.bg

    Connections {
        target: LauncherState
        function onVisibleChanged() {
            if (LauncherState.visible && content.active)
                content.reset()
        }
    }

    function reset() {
        content.launcherRoot.query = ""
        resultList.currentIndex = 0
        searchField.forceActiveFocus()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Rectangle {
            width: parent.width
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
                text: content.launcherRoot.query

                onTextChanged: content.launcherRoot.query = text

                Keys.onEscapePressed: LauncherState.visible = false
                Keys.onReturnPressed: content.launcherRoot.launch(resultList.currentModelData)
                Keys.onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, resultList.count - 1)
                Keys.onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
            }
        }

        NListView {
            id: resultList
            width: parent.width
            height: parent.height - searchField.height - parent.spacing
            model: content.launcherRoot.filteredApps
            currentIndex: 0

            property var currentModelData: count > 0 ? model[currentIndex] : null

            delegate: Rectangle {
                width: resultList.width
                height: 44
                radius: 6
                color: ListView.isCurrentItem ? Colors.pillActive : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10

                    IconImage {
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        source: Quickshell.iconPath(modelData.icon, true)
                    }

                    NText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: Colors.text
                        pointSize: Style.fontSizeL
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            PinDialogState.open(modelData.id, modelData.name, modelData.icon)
                            return
                        }
                        resultList.currentIndex = index
                        content.launcherRoot.launch(modelData)
                    }
                }
            }
        }
    }
}
