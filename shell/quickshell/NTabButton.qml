import QtQuick
import QtQuick.Layouts

// A single tab inside an NTabBar (adapted from Widgets/NTabButton.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section). Tooltip
// support (including its hover-delay timer) is restored (TooltipService.qml/
// Tooltip.qml now exist) - it was stripped when this was first ported since
// neither existed yet.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string tooltipText: ""
    property bool checked: false
    property int tabIndex: 0
    property real pointSize: Style.fontSizeM
    property bool isFirst: false
    property bool isLast: false

    property bool isHovered: false

    signal clicked

    Layout.fillHeight: true
    implicitWidth: contentLayout.implicitWidth + Style.margin2M

    topLeftRadius: isFirst ? Style.iRadiusM : Style.iRadiusXXXS
    bottomLeftRadius: isFirst ? Style.iRadiusM : Style.iRadiusXXXS
    topRightRadius: isLast ? Style.iRadiusM : Style.iRadiusXXXS
    bottomRightRadius: isLast ? Style.iRadiusM : Style.iRadiusXXXS

    color: root.isHovered ? Colors.mHover : (root.checked ? Colors.mPrimary : Colors.mSurface)
    border.color: root.checked ? Colors.mPrimary : Colors.mOutline
    border.width: Style.borderS

    Behavior on color {
        ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
    }

    RowLayout {
        id: contentLayout
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - Style.margin2S)
        spacing: (root.icon !== "" && root.text !== "") ? Style.marginXS : 0

        NIcon {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            icon: root.icon
            pointSize: root.pointSize * 1.2
            color: root.isHovered ? Colors.mOnHover : (root.checked ? Colors.mOnPrimary : Colors.mOnSurface)

            Behavior on color {
                ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
            }
        }

        NText {
            id: tabText
            visible: root.text !== ""
            Layout.alignment: Qt.AlignVCenter
            text: root.text
            pointSize: root.pointSize
            font.weight: Style.fontWeightSemiBold
            color: root.isHovered ? Colors.mOnHover : (root.checked ? Colors.mOnPrimary : Colors.mOnSurface)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
            }
        }
    }

    Timer {
        id: tooltipTimer
        interval: 500
        onTriggered: {
            if (root.isHovered && root.tooltipText !== "")
                TooltipService.show(root, root.tooltipText)
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            root.isHovered = true
            if (root.tooltipText !== "")
                tooltipTimer.start()
        }
        onExited: {
            root.isHovered = false
            tooltipTimer.stop()
            if (root.tooltipText !== "")
                TooltipService.hide()
        }
        onClicked: {
            tooltipTimer.stop()
            if (root.tooltipText !== "")
                TooltipService.hide()
            root.clicked()
            if (root.parent && root.parent.parent && root.parent.parent.currentIndex !== undefined)
                root.parent.parent.currentIndex = root.tabIndex
        }
    }
}
