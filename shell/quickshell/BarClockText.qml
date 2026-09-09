import QtQuick
import Quickshell

// The bar's clock, its own file since Bar.qml now uses it in two different
// spots depending on BarConfig.layoutMode - centered on its own in
// "statusbar" layout, inline as the second-to-last item in the right-side
// module row (before the Control Center launcher) in "taskbar" layout -
// rather than duplicating the SystemClock/CalendarFlyout wiring in both.
NText {
    id: clockText

    text: Qt.formatDateTime(clock.date, DateTimeConfig.clockFormat)
    color: Colors.text
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Opens CalendarFlyout.qml anchored below this clock - one shared
    // flyout instance retargeted to whichever monitor's clock was actually
    // clicked, see CalendarFlyoutState.qml.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (CalendarFlyoutState.targetItem === clockText)
                CalendarFlyoutState.visible = !CalendarFlyoutState.visible
            else {
                CalendarFlyoutState.targetItem = clockText
                CalendarFlyoutState.visible = true
            }
        }
    }
}
