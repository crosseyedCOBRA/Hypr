import QtQuick

// Circular icon-only button (adapted from Widgets/NIconButton.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section). Dropped
// the uiScaleRatio multiplier (Style.qml has no per-user dynamic scale
// here), tooltip support (no tooltip system yet), and smartAlpha
// translucency (no "translucent widgets" setting here) - colorBg is just
// mSurfaceVariant directly.
Item {
    id: root

    property real baseSize: Style.baseWidgetSize

    property string icon
    property bool allowClickWhenDisabled: false
    property bool handleWheel: false
    property bool hovering: false

    property color colorBg: Colors.mSurfaceVariant
    property color colorFg: Colors.mPrimary
    property color colorBgHover: Colors.mHover
    property color colorFgHover: Colors.mOnHover
    property color colorBorder: Colors.mOutline
    property color colorBorderHover: Colors.mOutline
    property real customRadius: -1 // -1 means use default (iRadiusL), otherwise use this value

    property alias border: visualButton.border
    property alias radius: visualButton.radius
    property alias color: visualButton.color

    signal entered
    signal exited
    signal clicked
    signal rightClicked
    signal middleClicked
    signal wheel(int angleDelta)

    readonly property real buttonSize: Style.toOdd(baseSize)

    implicitWidth: buttonSize
    implicitHeight: buttonSize

    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        id: visualButton
        width: root.buttonSize
        height: root.buttonSize
        anchors.centerIn: parent

        color: root.enabled && root.hovering ? colorBgHover : colorBg
        radius: Math.min((customRadius >= 0 ? customRadius : Style.iRadiusL), width / 2)
        border.color: root.enabled && root.hovering ? colorBorderHover : colorBorder
        border.width: Style.borderS

        Behavior on color {
            ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
        }

        NIcon {
            icon: root.icon
            pointSize: Style.toOdd(visualButton.width * 0.48)
            color: root.enabled && root.hovering ? colorFgHover : colorFg
            x: Style.pixelAlignCenter(visualButton.width, width)
            y: Style.pixelAlignCenter(visualButton.height, contentHeight)

            Behavior on color {
                ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
            }
        }
    }

    MouseArea {
        enabled: true
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        onEntered: {
            hovering = root.enabled ? true : false
            root.entered()
        }
        onExited: {
            hovering = false
            root.exited()
        }
        onClicked: mouse => {
            if (!root.enabled && !allowClickWhenDisabled)
                return
            if (mouse.button === Qt.LeftButton)
                root.clicked()
            else if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked()
        }
        onWheel: wheel => {
            if (root.handleWheel)
                root.wheel(wheel.angleDelta.y)
            wheel.accepted = false
        }
    }
}
