import QtQuick

// Current-conditions weather display (icon, temperature+condition,
// location+hi/lo) - its own file since it's now used in two places
// (Control Center's own Weather section, and CalendarFlyout.qml's) rather
// than duplicated between them. All the actual data/fetching lives in
// WeatherService.qml; this is purely presentation.
//
// The location line respects WeatherService.hideLocation (Settings'
// Profile tab "Hide location" toggle) - for anyone who doesn't want their
// city name visible in a panel that could end up in a screenshot or
// stream, the temperature/condition/hi-lo still shows, just not the place
// name itself.
Row {
    id: root

    property real iconPointSize: Style.fontSizeXXXL

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
