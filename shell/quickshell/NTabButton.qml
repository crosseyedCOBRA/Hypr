import QtQuick
import QtQuick.Layouts

// A single tab inside an NTabBar (adapted from Widgets/NTabButton.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section). Tooltip
// support and its hover-delay timer are stripped (no tooltip system yet).
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        onClicked: {
            root.clicked()
            if (root.parent && root.parent.parent && root.parent.parent.currentIndex !== undefined)
                root.parent.parent.currentIndex = root.tabIndex
        }
    }
}
