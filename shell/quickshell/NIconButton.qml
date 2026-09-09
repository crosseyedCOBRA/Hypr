import QtQuick

// Circular icon-only button (adapted from Widgets/NIconButton.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section). Dropped
// the uiScaleRatio multiplier (Style.qml has no per-user dynamic scale
// here) and smartAlpha translucency (no "translucent widgets" setting here)
// - colorBg is just mSurfaceVariant directly. Tooltip support is restored
// (TooltipService.qml/Tooltip.qml now exist) - it was stripped when this
// was first ported since neither existed yet.
Item {
    id: root

    property real baseSize: Style.baseWidgetSize

    property string icon
    property string tooltipText: ""
    property string tooltipDirection: "auto"
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
            // anchors.fill (rather than the x/y pixel math this used to
            // use, centering the glyph's own tight content bounding box as
            // a block) so NIcon's own horizontalAlignment/verticalAlignment
            // - already AlignHCenter/AlignVCenter, but inert without a
            // real width/height to center within - actually does the
            // centering via Qt's real text layout, which accounts for a
            // glyph's per-character advance width/side-bearing correctly.
            // Several Nerd Font icon glyphs (confirmed live via a throwaway
            // test harness rendering a glyph's tight content-box border
            // directly: the volume/speaker icon was the clearest offender)
            // have real, uneven left/right bearing baked into the font
            // itself - centering their tight content box as a single block
            // (the old approach) still left visibly more empty space on
            // one side than the other, which is what "icons are still off
            // center" was actually describing after the unrelated panel-
            // wide centering issue (NScrollView's padding) was already
            // fixed. Confirmed via the same test harness that this
            // approach renders visibly more centered for exactly that
            // glyph, not just in theory.
            anchors.fill: parent
            icon: root.icon
            pointSize: Style.toOdd(visualButton.width * 0.48)
            color: root.enabled && root.hovering ? colorFgHover : colorFg

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
            if (hovering && root.tooltipText !== "")
                TooltipService.show(root, root.tooltipText, root.tooltipDirection)
        }
        onExited: {
            hovering = false
            root.exited()
            if (root.tooltipText !== "")
                TooltipService.hide(root)
        }
        onClicked: mouse => {
            if (root.tooltipText !== "")
                TooltipService.hide(root)
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
