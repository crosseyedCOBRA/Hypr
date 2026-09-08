import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Rofi-style application launcher.
//
// Toggle it from anywhere (e.g. a ZarisWM keybind) with:
//   qs ipc call launcher toggle
//
// Usage counts are persisted to Quickshell's reserved state directory and
// used to sort results (most-launched first), so frequently used apps rise
// to the top over time.
FloatingWindow {
    id: launcherWindow

    visible: LauncherState.visible
    title: "Launcher"

    implicitWidth: 600
    implicitHeight: 420

    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherState.visible = !LauncherState.visible }
        function show(): void { LauncherState.visible = true }
        function hide(): void { LauncherState.visible = false }
    }

    // --- usage tracking ---

    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: usageData
            property var counts: ({})
        }
    }

    function launchCountFor(entryId) {
        return usageData.counts[entryId] || 0
    }

    function recordLaunch(entryId) {
        const updated = Object.assign({}, usageData.counts)
        updated[entryId] = (updated[entryId] || 0) + 1
        usageData.counts = updated
    }

    function launch(app) {
        if (!app)
            return

        recordLaunch(app.id)
        app.execute()
        LauncherState.visible = false
    }

    // --- filtering + usage-based sorting ---

    property string query: ""

    property var filteredApps: {
        const q = query.toLowerCase().trim()
        const all = DesktopEntries.applications.values

        const matches = q === "" ? all : all.filter(function (app) {
            if (app.name && app.name.toLowerCase().includes(q))
                return true
            if (app.comment && app.comment.toLowerCase().includes(q))
                return true
            if (app.keywords && app.keywords.some(function (k) { return k.toLowerCase().includes(q) }))
                return true
            if (app.categories && app.categories.some(function (c) { return c.toLowerCase().includes(q) }))
                return true
            return false
        })

        return matches.slice().sort(function (a, b) {
            const byUsage = launchCountFor(b.id) - launchCountFor(a.id)
            return byUsage !== 0 ? byUsage : a.name.localeCompare(b.name)
        })
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
                    text: launcherWindow.query

                    onTextChanged: launcherWindow.query = text

                    Keys.onEscapePressed: LauncherState.visible = false
                    Keys.onReturnPressed: launcherWindow.launch(resultList.currentModelData)
                    Keys.onDownPressed: resultList.currentIndex = Math.min(resultList.currentIndex + 1, resultList.count - 1)
                    Keys.onUpPressed: resultList.currentIndex = Math.max(resultList.currentIndex - 1, 0)
                }
            }

            ListView {
                id: resultList
                width: parent.width
                height: parent.height - searchField.height - parent.spacing
                clip: true
                model: launcherWindow.filteredApps
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: Colors.text
                            font.pixelSize: 15
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
                            launcherWindow.launch(modelData)
                        }
                    }
                }
            }
        }
    }
}
