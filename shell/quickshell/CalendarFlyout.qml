import QtQuick
import Quickshell

// Calendar flyout - opens under the bar's clock on click, fulfilling the
// "calendar flyout on clock click" backlog item. NOT a port of Noctalia's
// Services/Location/CalendarService.qml + Modules/Cards/
// CalendarMonthCard.qml/CalendarHeaderCard.qml, despite fulfilling the
// same item. CalendarService is built entirely around real calendar-event
// backends (khal, GNOME Evolution Data Server) - a genuine architecture
// decision (which backend(s) to support, if any) not yet made, same
// category as the clipboard-mechanism decision. CalendarHeaderCard is
// separately entangled with Noctalia's weather/location system and its
// own analog/digital clock widget, neither of which exists here - the bar
// already has its own clock. The actual month-grid logic (day-of-week
// offsets, padding, "which cell is today") now lives in CalendarWidget.qml,
// shared with Control Center's own Calendar section below.
//
// Also now shows current weather (WeatherWidget.qml, also shared with
// Control Center) underneath the grid, per explicit request - the same
// data Control Center already displayed, just not previously duplicated
// here.
//
// Built on PopupWindow rather than a FloatingWindow, same reasoning as
// Tooltip.qml: anchors directly to an arbitrary target Item (here, the
// clicked bar's clock Text) via `anchor.item`, needing none of Zaris's
// WM-side windowrule system. Rather than one instance per monitor (which
// would mean restructuring Bar.qml's per-screen Variants to wrap multiple
// windows per delegate, e.g. like Dock.qml's floating/reserved variant
// pair), this is a single shared instance whose target is reassigned by
// whichever bar's clock was actually clicked - CalendarFlyoutState.qml
// holds that shared, retargetable state, the same "one instance, retarget
// per interaction" approach Tooltip already uses for hover targets.
PopupWindow {
    id: root

    visible: CalendarFlyoutState.visible && !!CalendarFlyoutState.targetItem
    color: "transparent"

    // Widened from the original 260 to comfortably fit the weather row
    // added below the calendar grid - implicitHeight stays computed from
    // body's own implicitHeight, so adding weather grew the window's
    // height automatically with no hardcoded value to update.
    implicitWidth: 300
    implicitHeight: body.implicitHeight + 20

    anchor.item: CalendarFlyoutState.targetItem
    anchor.rect.x: CalendarFlyoutState.targetItem ? (CalendarFlyoutState.targetItem.width - implicitWidth) / 2 : 0
    // Opens above the bar instead of below it when BarConfig.position is
    // "bottom" - see BarConfig.popupAnchorY's own comment. The clock this
    // anchors to can now live in a bottom-positioned bar too (either layout
    // mode), not just a top one, so this can no longer be a fixed
    // downward-only offset.
    anchor.rect.y: BarConfig.popupAnchorY(CalendarFlyoutState.targetItem, implicitHeight)

    Rectangle {
        anchors.fill: parent
        color: Colors.mSurface
        border.color: Colors.mOutline
        border.width: Style.borderS
        radius: Style.radiusM

        Column {
            id: body
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            CalendarWidget {
                width: parent.width
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.mOutline
                opacity: 0.4
            }

            WeatherWidget {
                width: parent.width
                iconPointSize: Style.fontSizeXXL
            }
        }
    }
}
