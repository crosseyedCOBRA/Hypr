import QtQuick
import QtQuick.Layouts

// Filled/outlined button with optional icon (adapted from
// Widgets/NButton.qml, MIT licensed, v4.7.7 - see README.md's "Third-party
// code" section). The live color-transition guard (`!Color.isTransitioning`)
// is stripped - Zaris's colors are static constants, never reassigned at
// runtime, so there's nothing to guard a transition against. Tooltip
// support is restored (TooltipService.qml/Tooltip.qml now exist) - it was
// stripped when this was first ported since neither existed yet.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string tooltipText: ""
    property color backgroundColor: Colors.mPrimary
    property color textColor: Colors.mOnPrimary
    property color hoverColor: Colors.mHover
    property color textHoverColor: Colors.mOnHover
    property real fontSize: Style.fontSizeM
    property int fontWeight: Style.fontWeightSemiBold
    property real iconSize: Style.fontSizeL
    property bool outlined: false
    property int horizontalAlignment: Qt.AlignHCenter
    property real buttonRadius: Style.iRadiusS

    signal clicked
    signal rightClicked
    signal middleClicked
    signal entered
    signal exited

    property bool hovered: false
    readonly property color contentColor: {
        if (!root.enabled)
            return Colors.mOnSurfaceVariant
        if (root.hovered)
            return root.textHoverColor
        if (root.outlined)
            return root.backgroundColor
        return root.textColor
    }

    implicitWidth: bg.implicitWidth + 2 * Style.borderS
    implicitHeight: bg.implicitHeight + 2 * Style.borderS

    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: Style.borderS

        implicitWidth: contentRow.implicitWidth + (root.fontSize * 2)
        implicitHeight: contentRow.implicitHeight + (root.fontSize)

        radius: root.buttonRadius
        color: {
            if (!root.enabled)
                return root.outlined ? "transparent" : Qt.lighter(Colors.mSurfaceVariant, 1.2)
            if (root.hovered)
                return root.hoverColor
            return root.outlined ? "transparent" : root.backgroundColor
        }

        border.width: root.outlined ? Style.borderS : 0
        border.color: {
            if (!root.enabled)
                return Colors.mOutline
            if (root.hovered)
                return root.hoverColor
            return root.outlined ? root.backgroundColor : "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.horizontalAlignment === Qt.AlignLeft ? parent.left : undefined
            anchors.horizontalCenter: root.horizontalAlignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
            anchors.leftMargin: root.horizontalAlignment === Qt.AlignLeft ? Style.marginL : 0
            spacing: Style.marginXS

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.icon !== ""
                icon: root.icon
                pointSize: root.iconSize
                color: root.contentColor

                Behavior on color {
                    ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
                }
            }

            NText {
                Layout.alignment: Qt.AlignVCenter
                visible: root.text !== ""
                text: root.text
                pointSize: root.fontSize
                font.weight: root.fontWeight
                color: root.contentColor

                Behavior on color {
                    ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: root.enabled
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onEntered: {
                root.hovered = root.enabled ? true : false
                root.entered()
                if (root.hovered && root.tooltipText !== "")
                    TooltipService.show(root, root.tooltipText)
            }
            onExited: {
                root.hovered = false
                root.exited()
                if (root.tooltipText !== "")
                    TooltipService.hide()
            }
            onPressed: mouse => {
                if (root.tooltipText !== "")
                    TooltipService.hide()
                if (mouse.button === Qt.LeftButton)
                    root.clicked()
                else if (mouse.button === Qt.RightButton)
                    root.rightClicked()
                else if (mouse.button === Qt.MiddleButton)
                    root.middleClicked()
            }
            onCanceled: {
                root.hovered = false
                if (root.tooltipText !== "")
                    TooltipService.hide()
            }
        }
    }
}
