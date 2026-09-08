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
// already has its own clock. What's actually portable and worth keeping is
// CalendarMonthCard's month-grid generation and navigation logic - pure JS
// date math (day-of-week offsets, "days from previous/next month to pad
// the grid", "which cell is today") with zero external coupling - ported
// close to verbatim below. No event integration (no dots, no per-day
// tooltips, no click-to-open-gnome-calendar) since there's no event data
// to show yet; this is a plain date-browsing calendar for now.
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

    implicitWidth: 260
    implicitHeight: body.implicitHeight + 20

    anchor.item: CalendarFlyoutState.targetItem
    anchor.rect.x: CalendarFlyoutState.targetItem ? (CalendarFlyoutState.targetItem.width - implicitWidth) / 2 : 0
    anchor.rect.y: CalendarFlyoutState.targetItem ? CalendarFlyoutState.targetItem.height + 10 : 0

    readonly property var todayDate: new Date()
    property int viewMonth: todayDate.getMonth()
    property int viewYear: todayDate.getFullYear()
    // Sunday - matches the bar clock's own hardcoded English date format,
    // there's no locale/I18n system here to derive this from.
    readonly property int firstDayOfWeek: 0

    function goToPreviousMonth() {
        const d = new Date(viewYear, viewMonth - 1, 1)
        viewYear = d.getFullYear()
        viewMonth = d.getMonth()
    }

    function goToNextMonth() {
        const d = new Date(viewYear, viewMonth + 1, 1)
        viewYear = d.getFullYear()
        viewMonth = d.getMonth()
    }

    function goToToday() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    // Ported near-verbatim from Noctalia's CalendarMonthCard.qml daysModel -
    // pure date math, no external coupling.
    readonly property var daysModel: {
        const firstOfMonth = new Date(viewYear, viewMonth, 1)
        const lastOfMonth = new Date(viewYear, viewMonth + 1, 0)
        const daysInMonth = lastOfMonth.getDate()
        const firstOfMonthDayOfWeek = firstOfMonth.getDay()
        const daysBefore = (firstOfMonthDayOfWeek - firstDayOfWeek + 7) % 7
        const lastOfMonthDayOfWeek = lastOfMonth.getDay()
        const daysAfter = (firstDayOfWeek - lastOfMonthDayOfWeek - 1 + 7) % 7
        const days = []
        const now = new Date()

        const prevMonth = new Date(viewYear, viewMonth, 0)
        const prevMonthDays = prevMonth.getDate()
        for (let i = daysBefore - 1; i >= 0; i--)
            days.push({ day: prevMonthDays - i, currentMonth: false, today: false })

        for (let day = 1; day <= daysInMonth; day++) {
            const isToday = viewYear === now.getFullYear() && viewMonth === now.getMonth() && day === now.getDate()
            days.push({ day: day, currentMonth: true, today: isToday })
        }

        for (let i = 1; i <= daysAfter; i++)
            days.push({ day: i, currentMonth: false, today: false })

        return days
    }

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
            spacing: 8

            Row {
                width: parent.width
                height: 24

                NIconButton {
                    icon: ""
                    baseSize: 22
                    tooltipText: "Previous month"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.goToPreviousMonth()
                }

                NText {
                    width: parent.width - 66
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.locale().monthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold
                    color: Colors.mOnSurface
                }

                NIconButton {
                    icon: ""
                    baseSize: 22
                    tooltipText: "Next month"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: root.goToNextMonth()
                }
            }

            Row {
                width: parent.width

                Repeater {
                    model: 7
                    NText {
                        required property int index
                        width: body.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((root.firstDayOfWeek + index) % 7, Locale.ShortFormat).substring(0, 2).toUpperCase()
                        pointSize: Style.fontSizeXS
                        font.weight: Style.fontWeightBold
                        color: Colors.mPrimary
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7

                Repeater {
                    model: root.daysModel

                    Item {
                        required property var modelData
                        width: body.width / 7
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData.today ? Colors.mSecondary : "transparent"

                            NText {
                                anchors.centerIn: parent
                                text: modelData.day
                                pointSize: Style.fontSizeS
                                opacity: modelData.currentMonth ? 1.0 : 0.35
                                color: modelData.today ? Colors.mOnSecondary : Colors.mOnSurface
                                font.weight: modelData.today ? Style.fontWeightBold : Style.fontWeightRegular
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 20

                NText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Today"
                    pointSize: Style.fontSizeXS
                    color: Colors.mPrimary

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday()
                    }
                }
            }
        }
    }
}
