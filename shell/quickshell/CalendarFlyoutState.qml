pragma Singleton
import QtQuick

// Shared state for CalendarFlyout.qml - one flyout instance, anchored
// dynamically to whichever monitor's bar clock was clicked (each Bar.qml
// instance retargets this to its own clock Text on click), the same
// "one shared instance, retargeted per click" approach Tooltip.qml/
// TooltipService.qml use for hover targets.
QtObject {
    property bool visible: false
    property Item targetItem: null
}
