import QtQuick

// Small dot indicating a setting differs from its default, with a hover
// tooltip (adapted from Widgets/NSettingsIndicator.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section). The tooltip is
// restored (TooltipService.qml/Tooltip.qml now exist) - it was stripped
// when this was first ported since neither existed yet.
Rectangle {
    id: root

    property bool show: false
    property string tooltipText: ""

    implicitWidth: show ? 6 : 0
    implicitHeight: show ? 6 : 0
    width: show ? 6 : 0
    height: show ? 6 : 0
    radius: width / 2
    color: Colors.mOnSurfaceVariant
    opacity: 0.6
    visible: show

    Behavior on opacity {
        NumberAnimation { duration: Style.animationFast }
    }

    MouseArea {
        enabled: root.show && root.tooltipText !== ""
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            if (root.tooltipText !== "")
                TooltipService.show(root, root.tooltipText)
        }
        onExited: {
            if (root.tooltipText !== "")
                TooltipService.hide()
        }
    }
}
