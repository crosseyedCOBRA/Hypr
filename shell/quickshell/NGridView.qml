import QtQuick
import QtQuick.Controls

// GridView wrapper with the same custom-styled scrollbar, edge-fade
// gradient masks, and smooth animated mouse-wheel scrolling as
// NListView.qml/NScrollView.qml (adapted from Widgets/NGridView.qml, MIT
// licensed, v4.7.7 - see README.md's "Third-party code" section) -
// forwards most of GridView's own properties/methods via aliases so it's
// a drop-in replacement wherever a plain GridView would otherwise go
// (e.g. WallpaperPickerPanel.qml's thumbnail grid could migrate to this
// later for the same scrollbar/gradient polish, not done as part of this
// port). Same three per-user settings toggles fixed to their more
// polished default as NScrollView.qml/NListView.qml, for the same reason
// (no per-user settings system here).
Item {
    id: root

    signal keyPressed(var event)

    property color handleColor: Qt.alpha(Colors.mHover, 0.8)
    property color handleHoverColor: handleColor
    property color handlePressedColor: handleColor
    property color trackColor: "transparent"
    property real handleWidth: 6
    property real handleRadius: Style.iRadiusM
    property int verticalPolicy: ScrollBar.AsNeeded
    property int horizontalPolicy: ScrollBar.AlwaysOff
    readonly property bool verticalScrollBarActive: {
        if (gridView.ScrollBar.vertical.policy === ScrollBar.AlwaysOff)
            return false
        return gridView.contentHeight > gridView.height
    }
    readonly property bool contentOverflows: gridView.contentHeight > gridView.height

    property bool showGradientMasks: true
    property color gradientColor: Colors.mSurfaceVariant
    property int gradientHeight: 16
    property bool reserveScrollbarSpace: true

    readonly property bool showScrollbarWhenScrollable: false

    // Note: always reserves scrollbar space when enabled, to avoid
    // binding loops with cellWidth calculations.
    readonly property real availableWidth: width - (reserveScrollbarSpace ? handleWidth + Style.marginXS : 0)

    readonly property bool hasActiveFocus: gridView.activeFocus

    property alias model: gridView.model
    property alias delegate: gridView.delegate
    property alias cellWidth: gridView.cellWidth
    property alias cellHeight: gridView.cellHeight
    property alias leftMargin: gridView.leftMargin
    property alias rightMargin: gridView.rightMargin
    property alias topMargin: gridView.topMargin
    property alias bottomMargin: gridView.bottomMargin
    property alias currentIndex: gridView.currentIndex
    property alias count: gridView.count
    property alias contentHeight: gridView.contentHeight
    property alias contentWidth: gridView.contentWidth
    property alias contentY: gridView.contentY
    property alias contentX: gridView.contentX
    property alias currentItem: gridView.currentItem
    property alias highlightItem: gridView.highlightItem
    property alias highlightFollowsCurrentItem: gridView.highlightFollowsCurrentItem
    property alias preferredHighlightBegin: gridView.preferredHighlightBegin
    property alias preferredHighlightEnd: gridView.preferredHighlightEnd
    property alias highlightRangeMode: gridView.highlightRangeMode
    property alias snapMode: gridView.snapMode
    property alias keyNavigationEnabled: gridView.keyNavigationEnabled
    property alias keyNavigationWraps: gridView.keyNavigationWraps
    property alias cacheBuffer: gridView.cacheBuffer
    property alias displayMarginBeginning: gridView.displayMarginBeginning
    property alias displayMarginEnd: gridView.displayMarginEnd
    property alias layoutDirection: gridView.layoutDirection
    property alias effectiveLayoutDirection: gridView.effectiveLayoutDirection
    property alias flow: gridView.flow
    property alias boundsBehavior: gridView.boundsBehavior
    property alias flickableDirection: gridView.flickableDirection
    property alias interactive: gridView.interactive
    property alias moving: gridView.moving
    property alias flicking: gridView.flicking
    property alias dragging: gridView.dragging
    property alias horizontalVelocity: gridView.horizontalVelocity
    property alias verticalVelocity: gridView.verticalVelocity
    property alias reuseItems: gridView.reuseItems

    // Animate items when the model is reordered (e.g. ListModel.move()).
    property bool animateMovement: false

    property real wheelScrollMultiplier: 2.0
    property int smoothWheelAnimationDuration: Style.animationNormal
    property real _wheelTargetY: 0

    function clampScrollY(value) {
        return Math.max(0, Math.min(value, gridView.contentHeight - gridView.height))
    }

    function applyWheelScroll(delta) {
        if (!root.contentOverflows)
            return

        const step = delta * root.wheelScrollMultiplier

        if (!wheelScrollAnimation.running)
            root._wheelTargetY = gridView.contentY

        root._wheelTargetY = root.clampScrollY(root._wheelTargetY - step)
        wheelScrollAnimation.to = root._wheelTargetY
        wheelScrollAnimation.restart()
    }

    function animateToContentY(targetY) {
        const clampedY = root.clampScrollY(targetY)

        if (gridView.dragging || gridView.flicking) {
            gridView.contentY = clampedY
            root._wheelTargetY = clampedY
            return
        }

        root._wheelTargetY = clampedY
        wheelScrollAnimation.to = clampedY
        wheelScrollAnimation.restart()
    }

    // Set externally to keep the gradient mask hidden when the current
    // selection sits on the first/last visible row (so it doesn't visually
    // clip the very item that's selected).
    property int trackedSelectionIndex: -1

    readonly property bool selectionOnFirstVisibleRow: {
        if (trackedSelectionIndex < 0 || cellHeight <= 0 || cellWidth <= 0)
            return false
        let cols = Math.floor(gridView.width / cellWidth)
        if (cols <= 0)
            cols = 1
        const selectionRow = Math.round(trackedSelectionIndex / cols)
        const firstVisibleRow = Math.round(gridView.contentY / cellHeight)
        return selectionRow === firstVisibleRow
    }

    readonly property bool selectionOnLastVisibleRow: {
        if (trackedSelectionIndex < 0 || cellHeight <= 0 || cellWidth <= 0)
            return false
        let cols = Math.floor(gridView.width / cellWidth)
        if (cols <= 0)
            cols = 1
        const selectionRow = Math.round(trackedSelectionIndex / cols)
        const lastVisibleRow = Math.round((gridView.contentY + gridView.height - 1) / cellHeight)
        return selectionRow === lastVisibleRow
    }

    function positionViewAtIndex(index, mode) {
        const shouldAnimate = mode === GridView.Contain
        if (!shouldAnimate) {
            gridView.positionViewAtIndex(index, mode)
            root._wheelTargetY = gridView.contentY
            return
        }

        const previousY = gridView.contentY
        gridView.positionViewAtIndex(index, mode)
        const targetY = root.clampScrollY(gridView.contentY)

        if (Math.abs(targetY - previousY) < 0.5) {
            root._wheelTargetY = targetY
            return
        }

        gridView.contentY = previousY
        root._wheelTargetY = previousY
        root.animateToContentY(targetY)
    }

    function positionViewAtBeginning() { gridView.positionViewAtBeginning() }
    function positionViewAtEnd() { gridView.positionViewAtEnd() }
    function forceLayout() { gridView.forceLayout() }
    function forceActiveFocus() { gridView.forceActiveFocus() }
    function cancelFlick() { gridView.cancelFlick() }
    function flick(xVelocity, yVelocity) { gridView.flick(xVelocity, yVelocity) }
    function incrementCurrentIndex() { gridView.incrementCurrentIndex() }
    function decrementCurrentIndex() { gridView.decrementCurrentIndex() }
    function indexAt(x, y) { return gridView.indexAt(x, y) }
    function itemAt(x, y) { return gridView.itemAt(x, y) }
    function itemAtIndex(index) { return gridView.itemAtIndex(index) }
    function moveCurrentIndexUp() { gridView.moveCurrentIndexUp() }
    function moveCurrentIndexDown() { gridView.moveCurrentIndexDown() }
    function moveCurrentIndexLeft() { gridView.moveCurrentIndexLeft() }
    function moveCurrentIndexRight() { gridView.moveCurrentIndexRight() }

    implicitWidth: 200
    implicitHeight: 200

    Component.onCompleted: {
        _wheelTargetY = gridView.contentY
        createGradients()
    }

    function createGradients() {
        if (!showGradientMasks)
            return

        Qt.createQmlObject(`
      import QtQuick
      Rectangle {
        x: 0
        y: 0
        width: root.availableWidth
        height: root.gradientHeight
        z: 1
        visible: root.showGradientMasks && root.contentOverflows
        opacity: (gridView.contentY <= 1 || root.selectionOnFirstVisibleRow) ? 0 : 1
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
        x: 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        width: root.availableWidth
        height: root.gradientHeight + 1
        z: 1
        visible: root.showGradientMasks && root.contentOverflows
        opacity: ((gridView.contentY + gridView.height >= gridView.contentHeight - 1) || root.selectionOnLastVisibleRow) ? 0 : 1
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

    GridView {
        id: gridView
        anchors.fill: parent
        anchors.rightMargin: root.reserveScrollbarSpace ? root.handleWidth + Style.marginXS : 0

        move: root.animateMovement ? moveTransitionImpl : null
        displaced: root.animateMovement ? displacedTransitionImpl : null

        Transition {
            id: moveTransitionImpl
            NumberAnimation { properties: "x,y"; duration: Style.animationNormal; easing.type: Easing.InOutQuad }
        }
        Transition {
            id: displacedTransitionImpl
            NumberAnimation { properties: "x,y"; duration: Style.animationNormal; easing.type: Easing.InOutQuad }
        }

        clip: true
        boundsBehavior: Flickable.StopAtBounds

        NumberAnimation {
            id: wheelScrollAnimation
            target: gridView
            property: "contentY"
            duration: root.smoothWheelAnimationDuration
            easing.type: Easing.OutCubic
        }

        onDraggingChanged: {
            if (dragging) {
                wheelScrollAnimation.stop()
                root._wheelTargetY = contentY
            }
        }

        onFlickingChanged: {
            if (flicking) {
                wheelScrollAnimation.stop()
                root._wheelTargetY = contentY
            }
        }

        onContentHeightChanged: root._wheelTargetY = root.clampScrollY(root._wheelTargetY)
        onHeightChanged: root._wheelTargetY = root.clampScrollY(root._wheelTargetY)

        focus: keyNavigationEnabled
        activeFocusOnTab: keyNavigationEnabled

        Keys.onPressed: event => {
            if (keyNavigationEnabled)
                root.keyPressed(event)
        }

        WheelHandler {
            enabled: root.wheelScrollMultiplier !== 1.0
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 2
                root.applyWheelScroll(delta)
                event.accepted = true
            }
        }

        ScrollBar.vertical: ScrollBar {
            parent: root
            x: root.mirrored ? 0 : root.width - width
            y: 0
            height: root.height
            policy: root.verticalPolicy

            contentItem: Rectangle {
                implicitWidth: root.handleWidth
                implicitHeight: 100
                radius: root.handleRadius
                color: parent.pressed ? root.handlePressedColor : parent.hovered ? root.handleHoverColor : root.handleColor
                opacity: parent.policy === ScrollBar.AlwaysOn ? 1.0 : root.verticalScrollBarActive ? ((root.showScrollbarWhenScrollable || parent.active) ? 1.0 : 0.0) : 0.0

                Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
                Behavior on color { ColorAnimation { duration: Style.animationFast } }
            }

            background: Rectangle {
                implicitWidth: root.handleWidth
                implicitHeight: 100
                color: root.trackColor
                opacity: parent.policy === ScrollBar.AlwaysOn ? 0.3 : root.verticalScrollBarActive ? ((root.showScrollbarWhenScrollable || parent.active) ? 0.3 : 0.0) : 0.0
                radius: root.handleRadius / 2

                Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
            }
        }
    }
}
