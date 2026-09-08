import QtQuick

// Circular icon button with a "hot"/highlighted state variant, distinct
// from the plain hover state (adapted from Widgets/NIconButtonHot.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section). Tooltip
// support stripped (no tooltip system yet), uiScaleRatio dropped (no
// per-user dynamic scale here).
Rectangle {
    id: root

    property real baseSize: Style.baseWidgetSize
    property string icon
    property bool allowClickWhenDisabled: false
    property bool hot: false

    property bool hovering: false
    property bool pressed: false

    property color colorBg: Colors.mSurfaceVariant
    property color colorFg: Colors.mPrimary
    property color colorBgHover: Colors.mHover
    property color colorFgHover: Colors.mOnHover
    property color colorBorder: Colors.mOutline
    property color colorBorderHover: Colors.mOutline

    property color colorBgHot: Colors.mPrimary
    property color colorFgHot: Colors.mOnPrimary

    signal entered
    signal exited
    signal clicked
    signal rightClicked
    signal middleClicked

    implicitWidth: Math.round(baseSize)
    implicitHeight: Math.round(baseSize)

    opacity: enabled ? 1.0 : 0.6
    color: {
        if (root.enabled && root.hovering || pressed)
            return colorBgHover
        if (hot)
            return colorBgHot
        return colorBg
    }
    radius: Math.min(Style.iRadiusL, width / 2)
    border.color: root.enabled && root.hovering ? colorBorderHover : colorBorder
    border.width: Style.borderS

    Behavior on color {
        ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
    }

    NIcon {
        icon: root.icon
        pointSize: Math.max(1, Math.round(root.width * 0.48))
        color: {
            if (root.enabled && root.hovering || pressed)
                return colorFgHover
            if (hot)
                return colorFgHot
            return colorFg
        }
        x: (root.width - width) / 2
        y: (root.height - height) / 2 + (height - contentHeight) / 2

        Behavior on color {
            ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
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
        onPressed: function (mouse) {
            if (root.enabled)
                root.pressed = true
        }
        onReleased: function (mouse) {
            root.scale = 1.0
            root.pressed = false
            if (!root.enabled && !allowClickWhenDisabled)
                return
            if (root.hovering) {
                if (mouse.button === Qt.LeftButton)
                    root.clicked()
                else if (mouse.button === Qt.RightButton)
                    root.rightClicked()
                else if (mouse.button === Qt.MiddleButton)
                    root.middleClicked()
            }
        }
        onCanceled: {
            root.hovering = false
            root.pressed = false
            root.scale = 1.0
        }
    }
}
