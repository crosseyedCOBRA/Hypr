import QtQuick
import Quickshell

// The actual tooltip bubble - adapted from Noctalia's Modules/Tooltip/
// Tooltip.qml (MIT licensed, v4.7.7 - see README.md's "Third-party code"
// section), trimmed of its grid-mode (a multi-column table layout inside
// the tooltip) since nothing ported into Zaris so far needs anything but
// plain text, and its per-user font-family override (Zaris's NText has no
// such override either, by the same simplification already made there).
//
// Built on Quickshell's own PopupWindow type rather than a FloatingWindow -
// a real, distinct mechanism: PopupWindow anchors itself relative to a
// `parentWindow` (or, as used here, an arbitrary `anchor.item`) using
// Quickshell's own native positioning, not Zaris's WM-side windowrule
// system. This is the first thing in the shell built this way rather than
// needing a `center`/`topright`/`bottomcenter` rule - worth remembering for
// future popups anchored to a specific existing element (e.g. a future
// calendar flyout under the clock) rather than reaching for a new WM-side
// rule by default.
//
// The "auto" direction logic (try bottom, then top, then right, then left,
// falling back to whichever has the most room; then clamp to stay on
// whichever monitor the target is actually on) is genuine, non-trivial,
// working logic worth keeping intact - not overhead to trim, same
// reasoning as MediaService's player-matching heuristic.
PopupWindow {
    id: root

    property string text: ""
    property string direction: "auto" // "auto", "left", "right", "top", "bottom"
    property int margin: Style.marginXS
    property int padding: Style.marginM
    property int delay: 0
    property int hideDelay: 0
    property int maxWidth: 340

    property int animationDuration: Style.animationFast
    property real animationScale: 0.85

    // Internal properties
    property var targetItem: null
    property real anchorX: 0
    property real anchorY: 0
    property bool isPositioned: false
    property bool animatingOut: true
    property int screenWidth: 1920
    property int screenHeight: 1080
    property int screenX: 0
    property int screenY: 0

    visible: false
    color: "transparent"

    anchor.item: targetItem
    anchor.rect.x: anchorX
    anchor.rect.y: anchorY

    Timer {
        id: showTimer
        interval: root.delay
        repeat: false
        onTriggered: root.positionAndShow()
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        repeat: false
        onTriggered: root.startHideAnimation()
    }

    ParallelAnimation {
        id: showAnimation

        PropertyAnimation {
            target: tooltipContainer
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }

        PropertyAnimation {
            target: tooltipContainer
            property: "scale"
            from: root.animationScale
            to: 1.0
            duration: root.animationDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    ParallelAnimation {
        id: hideAnimation

        PropertyAnimation {
            target: tooltipContainer
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: root.animationDuration * 0.75
            easing.type: Easing.InCubic
        }

        PropertyAnimation {
            target: tooltipContainer
            property: "scale"
            from: 1.0
            to: root.animationScale
            duration: root.animationDuration * 0.75
            easing.type: Easing.InCubic
        }

        onFinished: root.completeHide()
    }

    function show(target, content, customDirection, showDelay) {
        if (!target || !content || content === "")
            return

        root.delay = showDelay

        hideTimer.stop()
        showTimer.stop()
        hideAnimation.stop()
        animatingOut = false

        if (visible && targetItem !== target) {
            hideImmediately()
        }

        text = content.replace(/\n/g, '<br>')
        targetItem = target

        // Find which screen the target is actually on, so clamping below
        // uses the right monitor's bounds rather than always screen 0.
        const targetGlobal = target.mapToGlobal(target.width / 2, target.height / 2)
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i]
            if (targetGlobal.x >= s.x && targetGlobal.x < s.x + s.width && targetGlobal.y >= s.y && targetGlobal.y < s.y + s.height) {
                screenWidth = s.width
                screenHeight = s.height
                screenX = s.x
                screenY = s.y
                break
            }
        }

        tooltipContainer.opacity = 0.0
        tooltipContainer.scale = root.animationScale

        showTimer.start()
        direction = customDirection !== undefined ? customDirection : "auto"
    }

    function positionAndShow() {
        if (!targetItem || !targetItem.parent)
            return

        const contentWidth = tooltipText.implicitWidth
        const contentHeight = tooltipText.implicitHeight

        const tipWidth = Math.ceil(Math.min(contentWidth + (padding * 2), maxWidth))
        root.implicitWidth = tipWidth

        const tipHeight = Math.ceil(contentHeight + (padding * 2))
        root.implicitHeight = tipHeight

        const targetGlobalAbs = targetItem.mapToGlobal(0, 0)
        const targetGlobal = { x: targetGlobalAbs.x - screenX, y: targetGlobalAbs.y - screenY }
        const targetWidth = targetItem.width
        const targetHeight = targetItem.height

        var newAnchorX = 0
        var newAnchorY = 0
        var selectedPosition = null

        if (direction === "auto") {
            const spaceLeft = targetGlobal.x
            const spaceRight = screenWidth - (targetGlobal.x + targetWidth)
            const spaceTop = targetGlobal.y
            const spaceBottom = screenHeight - (targetGlobal.y + targetHeight)

            const positions = [
                { dir: "bottom", space: spaceBottom, x: (targetWidth - tipWidth) / 2, y: targetHeight + margin, fits: spaceBottom >= tipHeight + margin },
                { dir: "top", space: spaceTop, x: (targetWidth - tipWidth) / 2, y: -tipHeight - margin, fits: spaceTop >= tipHeight + margin },
                { dir: "right", space: spaceRight, x: targetWidth + margin, y: (targetHeight - tipHeight) / 2, fits: spaceRight >= tipWidth + margin },
                { dir: "left", space: spaceLeft, x: -tipWidth - margin, y: (targetHeight - tipHeight) / 2, fits: spaceLeft >= tipWidth + margin }
            ]

            for (var i = 0; i < positions.length; i++) {
                if (positions[i].fits) {
                    selectedPosition = positions[i]
                    break
                }
            }
            if (!selectedPosition) {
                positions.sort(function (a, b) { return b.space - a.space })
                selectedPosition = positions[0]
            }

            newAnchorX = selectedPosition.x
            newAnchorY = selectedPosition.y
        } else {
            switch (direction) {
            case "left":
                newAnchorX = -tipWidth - margin
                newAnchorY = (targetHeight - tipHeight) / 2
                break
            case "right":
                newAnchorX = targetWidth + margin
                newAnchorY = (targetHeight - tipHeight) / 2
                break
            case "top":
                newAnchorX = (targetWidth - tipWidth) / 2
                newAnchorY = -tipHeight - margin
                break
            case "bottom":
                newAnchorX = (targetWidth - tipWidth) / 2
                newAnchorY = targetHeight + margin
                break
            }
        }

        const effectiveDirection = direction === "auto" ? selectedPosition.dir : direction
        const isHorizontalTooltip = (effectiveDirection === "top" || effectiveDirection === "bottom")
        const isVerticalTooltip = (effectiveDirection === "left" || effectiveDirection === "right")

        const globalX = targetGlobal.x + newAnchorX
        if (globalX < 0) {
            const adjustedX = -targetGlobal.x + margin
            if (isHorizontalTooltip) {
                newAnchorX = adjustedX
            } else {
                const wouldOverlap = adjustedX < targetWidth && adjustedX + tipWidth > 0
                if (!wouldOverlap)
                    newAnchorX = adjustedX
            }
        } else if (globalX + tipWidth > screenWidth) {
            const adjustedX = screenWidth - targetGlobal.x - tipWidth - margin
            if (isHorizontalTooltip) {
                newAnchorX = adjustedX
            } else {
                const wouldOverlap = adjustedX < targetWidth && adjustedX + tipWidth > 0
                if (!wouldOverlap)
                    newAnchorX = adjustedX
            }
        }

        const globalY = targetGlobal.y + newAnchorY
        if (globalY < 0) {
            const adjustedY = -targetGlobal.y + margin
            if (isVerticalTooltip) {
                newAnchorY = adjustedY
            } else {
                const wouldOverlap = adjustedY < targetHeight && adjustedY + tipHeight > 0
                if (!wouldOverlap)
                    newAnchorY = adjustedY
            }
        } else if (globalY + tipHeight > screenHeight) {
            const adjustedY = screenHeight - targetGlobal.y - tipHeight - margin
            if (isVerticalTooltip) {
                newAnchorY = adjustedY
            } else {
                const wouldOverlap = adjustedY < targetHeight && adjustedY + tipHeight > 0
                if (!wouldOverlap)
                    newAnchorY = adjustedY
            }
        }

        anchorX = newAnchorX < 0 ? Math.floor(newAnchorX) : Math.round(newAnchorX)
        anchorY = newAnchorY < 0 ? Math.floor(newAnchorY) : Math.round(newAnchorY)
        isPositioned = true

        root.visible = true
        showAnimation.start()
    }

    function hide() {
        showTimer.stop()
        hideTimer.stop()

        if (hideDelay > 0 && visible && !animatingOut) {
            hideTimer.start()
        } else {
            startHideAnimation()
        }
    }

    function startHideAnimation() {
        if (!visible || animatingOut)
            return
        animatingOut = true
        showAnimation.stop()
        hideAnimation.start()
    }

    function completeHide() {
        visible = false
        animatingOut = false
        text = ""
        isPositioned = false
        tooltipContainer.opacity = 1.0
        tooltipContainer.scale = 1.0
    }

    function hideImmediately() {
        showTimer.stop()
        hideTimer.stop()
        showAnimation.stop()
        hideAnimation.stop()
        animatingOut = false
        completeHide()
    }

    function updateContent(newContent) {
        if (visible && targetItem) {
            text = newContent.replace(/\n/g, '<br>')
            Qt.callLater(updateContentDeferred)
        }
    }

    function updateContentDeferred() {
        if (!visible || !targetItem)
            return

        const contentWidth = tooltipText.implicitWidth
        const contentHeight = tooltipText.implicitHeight

        const tipWidth = Math.ceil(Math.min(contentWidth + (padding * 2), maxWidth))
        root.implicitWidth = tipWidth
        const tipHeight = Math.ceil(contentHeight + (padding * 2))
        root.implicitHeight = tipHeight
    }

    function reset() {
        showTimer.stop()
        hideTimer.stop()
        showAnimation.stop()
        hideAnimation.stop()
        visible = false
        animatingOut = false
        text = ""
        isPositioned = false
        delay = 0
        hideDelay = 0
        tooltipContainer.opacity = 1.0
        tooltipContainer.scale = 1.0
    }

    Item {
        id: tooltipContainer
        anchors.fill: parent

        opacity: 1.0
        scale: 1.0
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            anchors.margins: border.width
            color: Colors.mSurface
            border.color: Colors.mOutline
            border.width: Style.borderS
            radius: Math.min(Style.radiusS, Math.min(width, height) / 3)

            visible: root.text !== ""

            NText {
                id: tooltipText
                anchors.centerIn: parent
                anchors.margins: root.padding
                text: root.text
                pointSize: Style.fontSizeS
                color: Colors.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                width: Math.min(implicitWidth, root.maxWidth - (root.padding * 2))
                richTextEnabled: true
            }
        }
    }

    Component.onCompleted: reset()
    Component.onDestruction: reset()
}
