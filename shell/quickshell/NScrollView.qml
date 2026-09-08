import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

// ScrollView with custom-styled scrollbars, edge-fade gradient masks, and
// smooth animated mouse-wheel scrolling (adapted from Widgets/
// NScrollView.qml, MIT licensed, v4.7.7 - see README.md's "Third-party
// code" section). Stripped of three per-user settings toggles Zaris has no
// equivalent for, fixed to their more polished default instead of adding
// unused configurability: `Settings.data.ui.scrollbarAlwaysVisible` -> the
// scrollbar only shows while actively scrolling/hovered (`false`);
// `Settings.data.general.smoothScrollEnabled` -> smooth wheel-scroll
// animation is always on (`true`); `Settings.data.general.animationDisabled`
// -> animations are never globally disabled (`false`, matches every other
// ported widget - there's no such toggle anywhere else in this shell either).
ScrollView {
    id: root

    property color handleColor: Qt.alpha(Colors.mHover, 0.8)
    property color handleHoverColor: handleColor
    property color handlePressedColor: handleColor
    property color trackColor: "transparent"
    property real handleWidth: 6
    property real handleRadius: Style.iRadiusM
    property int verticalPolicy: ScrollBar.AsNeeded
    property int horizontalPolicy: ScrollBar.AsNeeded
    property bool preventHorizontalScroll: horizontalPolicy === ScrollBar.AlwaysOff
    property int boundsBehavior: Flickable.StopAtBounds
    readonly property bool verticalScrollable: (contentItem.contentHeight > contentItem.height) || (verticalPolicy == ScrollBar.AlwaysOn)
    readonly property bool horizontalScrollable: (contentItem.contentWidth > contentItem.width) || (horizontalPolicy == ScrollBar.AlwaysOn)
    property bool showGradientMasks: true
    property color gradientColor: Colors.mSurfaceVariant
    property int gradientHeight: 16
    property bool reserveScrollbarSpace: true
    property real userRightPadding: 0
    // Keep scrollbars visible whenever overflow exists (without forcing
    // visibility when not scrollable) - fixed off, see file header.
    readonly property bool showScrollbarWhenScrollable: false

    // Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster).
    property real wheelScrollMultiplier: 2.0
    property int smoothWheelAnimationDuration: Style.animationNormal
    property real _wheelTargetY: 0

    function clampScrollY(value) {
        if (!root._internalFlickable)
            return 0
        const flickable = root._internalFlickable
        return Math.max(0, Math.min(value, flickable.contentHeight - flickable.height))
    }

    function applyWheelScroll(delta) {
        if (!root._internalFlickable)
            return

        const flickable = root._internalFlickable
        const step = delta * root.wheelScrollMultiplier

        if (!wheelScrollAnimation.running)
            root._wheelTargetY = flickable.contentY

        root._wheelTargetY = root.clampScrollY(root._wheelTargetY - step)
        wheelScrollAnimation.to = root._wheelTargetY
        wheelScrollAnimation.restart()
    }

    rightPadding: userRightPadding + (reserveScrollbarSpace && verticalScrollable ? handleWidth + Style.marginXS : 0)

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    Component.onCompleted: {
        configureFlickable()
        createGradients()
    }

    // Dynamically created (rather than declared inline) to avoid
    // interfering with ScrollView's own content-item management.
    function createGradients() {
        if (!showGradientMasks)
            return

        Qt.createQmlObject(`
      import QtQuick
      Rectangle {
        x: root.leftPadding
        y: root.topPadding
        width: root.availableWidth
        height: root.gradientHeight
        z: 1
        visible: root.showGradientMasks && root.verticalScrollable
        opacity: root.contentItem.contentY <= 1 ? 0 : 1
        Behavior on opacity {
          NumberAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
        }
        gradient: Gradient {
          GradientStop { position: 0.0; color: root.gradientColor }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
    `, root, "topGradient")

        Qt.createQmlObject(`
      import QtQuick
      Rectangle {
        x: root.leftPadding
        y: root.height - root.bottomPadding - height + 1
        width: root.availableWidth
        height: root.gradientHeight + 1
        z: 1
        visible: root.showGradientMasks && root.verticalScrollable
        opacity: (root.contentItem.contentY + root.contentItem.height >= root.contentItem.contentHeight - 1) ? 0 : 1
        Behavior on opacity {
          NumberAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
        }
        gradient: Gradient {
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 1.0; color: root.gradientColor }
        }
      }
    `, root, "bottomGradient")
    }

    property Flickable _internalFlickable: null

    NumberAnimation {
        id: wheelScrollAnimation
        target: root._internalFlickable
        property: "contentY"
        duration: root.smoothWheelAnimationDuration
        easing.type: Easing.OutCubic
    }

    Connections {
        target: root._internalFlickable

        function onDraggingChanged() {
            if (!root._internalFlickable || !root._internalFlickable.dragging)
                return
            wheelScrollAnimation.stop()
            root._wheelTargetY = root._internalFlickable.contentY
        }

        function onFlickingChanged() {
            if (!root._internalFlickable || !root._internalFlickable.flicking)
                return
            wheelScrollAnimation.stop()
            root._wheelTargetY = root._internalFlickable.contentY
        }

        function onContentHeightChanged() {
            root._wheelTargetY = root.clampScrollY(root._wheelTargetY)
        }

        function onHeightChanged() {
            root._wheelTargetY = root.clampScrollY(root._wheelTargetY)
        }
    }

    function configureFlickable() {
        for (let i = 0; i < children.length; i++) {
            const child = children[i]
            if (child.toString().indexOf("Flickable") !== -1) {
                child.boundsBehavior = root.boundsBehavior
                root._internalFlickable = child

                if (root.preventHorizontalScroll) {
                    child.flickableDirection = Flickable.VerticalFlick
                    child.contentWidth = Qt.binding(() => child.width)
                }

                root._wheelTargetY = child.contentY
                break
            }
        }
    }

    WheelHandler {
        enabled: root.wheelScrollMultiplier !== 1.0 && root._internalFlickable !== null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
            root.applyWheelScroll(delta)
            event.accepted = true
        }
    }

    onHorizontalPolicyChanged: {
        preventHorizontalScroll = (horizontalPolicy === ScrollBar.AlwaysOff)
        configureFlickable()
    }

    ScrollBar.vertical: ScrollBar {
        parent: root
        x: root.mirrored ? 0 : root.width - width
        y: root.topPadding
        height: root.availableHeight
        policy: root.verticalPolicy
        interactive: root.verticalScrollable

        contentItem: Rectangle {
            implicitWidth: root.handleWidth
            implicitHeight: 100
            radius: root.handleRadius
            color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
            opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.verticalScrollable ? ((root.showScrollbarWhenScrollable || parent.active) ? 1.0 : 0.0) : 0.0

            Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
            Behavior on color { ColorAnimation { duration: Style.animationFast } }
        }

        background: Rectangle {
            implicitWidth: root.handleWidth
            implicitHeight: 100
            color: root.trackColor
            opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.verticalScrollable ? ((root.showScrollbarWhenScrollable || parent.active) ? 0.3 : 0.0) : 0.0
            radius: root.handleRadius / 2

            Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        }
    }

    ScrollBar.horizontal: ScrollBar {
        parent: root
        x: root.leftPadding
        y: root.height - height
        width: root.availableWidth
        policy: root.horizontalPolicy
        interactive: root.horizontalScrollable

        contentItem: Rectangle {
            implicitWidth: 100
            implicitHeight: root.handleWidth
            radius: root.handleRadius
            color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
            opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.horizontalScrollable ? ((root.showScrollbarWhenScrollable || parent.active) ? 1.0 : 0.0) : 0.0

            Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
            Behavior on color { ColorAnimation { duration: Style.animationFast } }
        }

        background: Rectangle {
            implicitWidth: 100
            implicitHeight: root.handleWidth
            color: root.trackColor
            opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.horizontalScrollable ? ((root.showScrollbarWhenScrollable || parent.active) ? 0.3 : 0.0) : 0.0
            radius: root.handleRadius / 2

            Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        }
    }
}
