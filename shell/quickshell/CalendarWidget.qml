import QtQuick

// Month-grid calendar (nav header, day-of-week row, day grid, "Today"
// link) - its own file since it's now used in two places (Control
// Center's own Calendar section, and CalendarFlyout.qml's popup) rather
// than duplicated between them. Each embedding gets its own independent
// instance/view-state - which month is currently displayed is a pure
// per-view concern, not global data worth sharing - the same "duplicate
// the self-contained piece" approach already used for
// cpuSource/cpuTempSource/gpuTempSource inside ControlCenter.qml.
//
// Ported near-verbatim month-grid generation/navigation logic (pure JS
// date math - day-of-week offsets, padding in the previous/next month's
// trailing/leading days, which cell is today) - see CalendarFlyout.qml's
// own header comment for the original Noctalia CalendarMonthCard.qml
// attribution and the reasoning for not porting event integration.
Column {
    id: root

    spacing: 8

    readonly property var todayDate: new Date()
    property int viewMonth: todayDate.getMonth()
    property int viewYear: todayDate.getFullYear()
    // Sunday - matches the bar clock's own hardcoded English date format,
    // there's no locale/I18n system here to derive this from.
    readonly property int firstDayOfWeek: 0

    function goToPreviousMonth() {
        const d = new Date(root.viewYear, root.viewMonth - 1, 1)
        root.viewYear = d.getFullYear()
        root.viewMonth = d.getMonth()
    }

    function goToNextMonth() {
        const d = new Date(root.viewYear, root.viewMonth + 1, 1)
        root.viewYear = d.getFullYear()
        root.viewMonth = d.getMonth()
    }

    function goToToday() {
        const now = new Date()
        root.viewYear = now.getFullYear()
        root.viewMonth = now.getMonth()
    }

    readonly property var daysModel: {
        const firstOfMonth = new Date(root.viewYear, root.viewMonth, 1)
        const lastOfMonth = new Date(root.viewYear, root.viewMonth + 1, 0)
        const daysInMonth = lastOfMonth.getDate()
        const firstOfMonthDayOfWeek = firstOfMonth.getDay()
        const daysBefore = (firstOfMonthDayOfWeek - root.firstDayOfWeek + 7) % 7
        const lastOfMonthDayOfWeek = lastOfMonth.getDay()
        const daysAfter = (root.firstDayOfWeek - lastOfMonthDayOfWeek - 1 + 7) % 7
        const days = []
        const now = new Date()

        const prevMonth = new Date(root.viewYear, root.viewMonth, 0)
        const prevMonthDays = prevMonth.getDate()
        for (let i = daysBefore - 1; i >= 0; i--)
            days.push({ day: prevMonthDays - i, currentMonth: false, today: false })

        for (let day = 1; day <= daysInMonth; day++) {
            const isToday = root.viewYear === now.getFullYear() && root.viewMonth === now.getMonth() && day === now.getDate()
            days.push({ day: day, currentMonth: true, today: isToday })
        }

        for (let i = 1; i <= daysAfter; i++)
            days.push({ day: i, currentMonth: false, today: false })

        return days
    }

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
                width: root.width / 7
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
                width: root.width / 7
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
