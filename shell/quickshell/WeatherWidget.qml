import QtQuick

// Current-conditions weather display (icon, temperature+condition,
// location+hi/lo) plus a 5-day forecast row underneath - its own file
// since it's now used in two places (Control Center's own Weather
// section, and CalendarFlyout.qml's) rather than duplicated between
// them. All the actual data/fetching lives in WeatherService.qml; this is
// purely presentation. Every embedder sets `width:` explicitly (same
// contract as CalendarWidget.qml/AudioMixer.qml) - the forecast row below
// needs a real width to divide evenly across 5 day cells.
//
// The location line respects WeatherService.hideLocation (Settings'
// Profile tab "Hide location" toggle) - for anyone who doesn't want their
// city name visible in a panel that could end up in a screenshot or
// stream, the temperature/condition/hi-lo still shows, just not the place
// name itself.
Column {
    id: root

    property real iconPointSize: Style.fontSizeXXXL

    spacing: 12

    Row {
        width: parent.width
        spacing: 12

        NText {
            text: WeatherService.haveData ? WeatherService.iconGlyphCurrent : ""
            color: Colors.blue
            pointSize: root.iconPointSize
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            NText {
                text: {
                    if (WeatherService.errorText !== "")
                        return "Weather unavailable"
                    if (!WeatherService.haveData)
                        return "Loading weather..."
                    return Math.round(WeatherService.temperatureF) + "°F  " + WeatherService.conditionTextCurrent
                }
                color: Colors.text
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
            }

            NText {
                visible: WeatherService.haveData
                text: (WeatherService.hideLocation ? "" : WeatherService.locationName + "  ") + "H:" + Math.round(WeatherService.highF) + "°  L:" + Math.round(WeatherService.lowF) + "°"
                color: Colors.textMuted
                pointSize: Style.fontSizeS
            }
        }
    }

    // 5-day forecast - WeatherService.forecastDays[0] is today (same data
    // as the current-conditions line above, just restated as the first
    // cell here for a consistent row rather than a special-cased 4-day
    // tail), the rest are the next 4 days.
    Row {
        width: parent.width
        visible: WeatherService.haveData && WeatherService.forecastDays.length > 0

        Repeater {
            model: WeatherService.forecastDays

            Column {
                id: dayCell
                required property var modelData
                width: root.width / 5
                spacing: 2

                NText {
                    text: dayCell.modelData.label
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.textMuted
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightBold
                }

                NText {
                    text: WeatherService.iconGlyph(dayCell.modelData.weatherCode, true)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.blue
                    pointSize: Style.fontSizeL
                }

                NText {
                    text: Math.round(dayCell.modelData.highF) + "°/" + Math.round(dayCell.modelData.lowF) + "°"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.text
                    pointSize: Style.fontSizeXS
                }
            }
        }
    }
}
