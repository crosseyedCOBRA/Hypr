import QtQuick
import Quickshell

// Notification history panel - a genuinely new UI (like
// ClipboardHistoryPanel.qml before it), built directly on
// NotificationHistoryService.qml's dunst-backed history rather than ported
// from anywhere. Filter tabs (All/Today/Yesterday/Earlier) and per-item
// delete + clear-all match the reference screenshot the user supplied.
FloatingWindow {
    id: panel

    visible: NotificationHistoryPanelState.visible
    title: "Notifications"

    implicitWidth: 420
    implicitHeight: 480

    property int currentTab: 0

    readonly property var now: new Date()

    function startOfDay(epochSeconds) {
        const d = new Date(epochSeconds * 1000)
        d.setHours(0, 0, 0, 0)
        return d.getTime() / 1000
    }

    readonly property real todayStart: startOfDay(Date.now() / 1000)
    readonly property real yesterdayStart: todayStart - 86400

    function bucketFor(epoch) {
        if (epoch >= panel.todayStart)
            return "today"
        if (epoch >= panel.yesterdayStart)
            return "yesterday"
        return "earlier"
    }

    function relativeTime(epoch) {
        const diff = Math.max(0, Date.now() / 1000 - epoch)
        if (diff < 60)
            return "now"
        if (diff < 3600)
            return Math.floor(diff / 60) + "m ago"
        if (diff < 86400)
            return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }

    readonly property var todayItems: NotificationHistoryService.notifications.filter(n => bucketFor(n.epoch) === "today")
    readonly property var yesterdayItems: NotificationHistoryService.notifications.filter(n => bucketFor(n.epoch) === "yesterday")
    readonly property var earlierItems: NotificationHistoryService.notifications.filter(n => bucketFor(n.epoch) === "earlier")

    readonly property var visibleItems: {
        if (currentTab === 1)
            return todayItems
        if (currentTab === 2)
            return yesterdayItems
        if (currentTab === 3)
            return earlierItems
        return NotificationHistoryService.notifications
    }

    onVisibleChanged: {
        if (visible)
            NotificationHistoryService.refresh()
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Item {
                width: parent.width
                height: 30

                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    NIcon {
                        icon: ""
                        color: Colors.purple
                        pointSize: Style.fontSizeXL
                    }

                    NText {
                        text: "Notifications"
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
                        icon: ""
                        tooltipText: "Clear all"
                        onClicked: NotificationHistoryService.clearAll()
                    }

                    NIconButton {
                        baseSize: 26
                        icon: ""
                        tooltipText: "Close"
                        onClicked: NotificationHistoryPanelState.visible = false
                    }
                }
            }

            NTabBar {
                width: parent.width

                NTabButton {
                    text: "All (" + NotificationHistoryService.notifications.length + ")"
                    pointSize: Style.fontSizeS
                    checked: panel.currentTab === 0
                    onClicked: panel.currentTab = 0
                }

                NTabButton {
                    text: "Today (" + panel.todayItems.length + ")"
                    pointSize: Style.fontSizeS
                    checked: panel.currentTab === 1
                    onClicked: panel.currentTab = 1
                }

                NTabButton {
                    text: "Yesterday (" + panel.yesterdayItems.length + ")"
                    pointSize: Style.fontSizeS
                    checked: panel.currentTab === 2
                    onClicked: panel.currentTab = 2
                }

                NTabButton {
                    text: "Earlier (" + panel.earlierItems.length + ")"
                    pointSize: Style.fontSizeS
                    checked: panel.currentTab === 3
                    onClicked: panel.currentTab = 3
                }
            }

            NListView {
                id: list
                width: parent.width
                height: parent.height - 70
                model: panel.visibleItems

                NText {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    text: "No notifications"
                    color: Colors.textMuted
                    pointSize: Style.fontSizeM
                }

                delegate: Rectangle {
                    width: list.width
                    height: bodyText.visible ? 78 : 54
                    radius: Style.radiusS
                    color: Colors.pill

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 20

                            Row {
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter

                                NIcon {
                                    icon: ""
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeM
                                }

                                NText {
                                    text: modelData.appName
                                    color: Colors.coral
                                    pointSize: Style.fontSizeS
                                    font.weight: Style.fontWeightBold
                                }

                                NText {
                                    text: panel.relativeTime(modelData.epoch)
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }

                            NIconButton {
                                anchors.right: parent.right
                                baseSize: 20
                                icon: ""
                                tooltipText: "Remove"
                                onClicked: NotificationHistoryService.removeById(modelData.id)
                            }
                        }

                        NText {
                            text: modelData.summary
                            width: parent.width
                            elide: Text.ElideRight
                            color: Colors.text
                            pointSize: Style.fontSizeM
                        }

                        NText {
                            id: bodyText
                            text: modelData.body
                            visible: modelData.body !== "" && modelData.body !== modelData.summary
                            width: parent.width
                            elide: Text.ElideRight
                            color: Colors.textMuted
                            pointSize: Style.fontSizeXS
                        }
                    }
                }
            }
        }
    }
}
