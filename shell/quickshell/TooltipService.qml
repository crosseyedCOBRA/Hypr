pragma Singleton
import QtQuick
import Quickshell

// Shared tooltip service - adapted from Noctalia's Services/UI/
// TooltipService.qml (MIT licensed, v4.7.7 - see README.md's "Third-party
// code" section), stripped of `Settings.data.ui.tooltipsEnabled` (no
// per-user settings persistence here - always enabled) and `Logger.*`
// calls (no such logging singleton in Zaris). One shared Tooltip instance
// is created/destroyed per show() call rather than a fixed pool, matching
// upstream's own approach - tooltips are short-lived and infrequent enough
// that this is simpler than pooling.
//
// This directly resolves a real gap from the earlier widget-library port:
// NButton/NIconButton/NTabButton/NSettingsIndicator each had their tooltip
// wiring fully stripped out when first ported, since neither this file nor
// Tooltip.qml existed yet. Tooltip support (a `tooltipText` property plus
// the hover-triggered show()/hide() calls) has been restored in all four
// now that both exist.
Singleton {
    id: root

    property var activeTooltip: null
    property var pendingTooltip: null

    property Component tooltipComponent: Component {
        Tooltip {}
    }

    function show(target, content, direction, delay) {
        if (!target || !content || content === "")
            return

        if (pendingTooltip) {
            pendingTooltip.hideImmediately()
            pendingTooltip.destroy()
            pendingTooltip = null
        }

        if (activeTooltip && activeTooltip.targetItem !== target) {
            activeTooltip.hideImmediately()
            activeTooltip = null
        }

        if (activeTooltip && activeTooltip.targetItem === target) {
            activeTooltip.updateContent(content)
            return activeTooltip
        }

        const newTooltip = tooltipComponent.createObject(null)

        if (newTooltip) {
            pendingTooltip = newTooltip

            newTooltip.visibleChanged.connect(() => {
                if (!newTooltip.visible) {
                    Qt.callLater(() => {
                        if (newTooltip && !newTooltip.visible) {
                            if (activeTooltip === newTooltip)
                                activeTooltip = null
                            if (pendingTooltip === newTooltip)
                                pendingTooltip = null
                            newTooltip.destroy()
                        }
                    })
                } else {
                    if (pendingTooltip === newTooltip) {
                        activeTooltip = newTooltip
                        pendingTooltip = null
                    }
                }
            })

            newTooltip.show(target, content, direction || "auto", delay !== undefined ? delay : Style.tooltipDelay)
            return newTooltip
        }

        return null
    }

    function hide(target) {
        if (target) {
            if (pendingTooltip && pendingTooltip.targetItem === target)
                pendingTooltip.hide()
            if (activeTooltip && activeTooltip.targetItem === target)
                activeTooltip.hide()
        } else {
            if (pendingTooltip)
                pendingTooltip.hide()
            if (activeTooltip)
                activeTooltip.hide()
        }
    }

    function hideImmediately() {
        if (pendingTooltip) {
            pendingTooltip.hideImmediately()
            pendingTooltip.destroy()
            pendingTooltip = null
        }
        if (activeTooltip) {
            activeTooltip.hideImmediately()
            activeTooltip.destroy()
            activeTooltip = null
        }
    }
}
