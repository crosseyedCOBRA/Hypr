import QtQuick

// Battery/power-device status bar icon - shows a tiered glyph plus the
// percentage, colored to flag low/critical charge. Hides itself entirely
// when there's no present battery device at all (this desktop's own
// internal power has none - see BatteryService.qml's header comment on
// what UPower device this was verified against), same "vanish rather than
// show empty" convention as MediaWidget.qml/NightLight.qml's tray label.
Item {
    id: root

    property color textColor: "white"
    property color warningColor: "orange"
    property color criticalColor: "red"

    readonly property bool present: BatteryService.batteryPresent
    readonly property color effectiveColor: {
        if (BatteryService.isCriticalBattery(BatteryService.primaryDevice))
            return root.criticalColor
        if (BatteryService.isLowBattery(BatteryService.primaryDevice))
            return root.warningColor
        return root.textColor
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4

        Text {
            text: BatteryService.batteryIcon
            color: root.effectiveColor
            font.pixelSize: 13
        }

        Text {
            text: BatteryService.batteryPercentage + "%"
            color: root.effectiveColor
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: TooltipService.show(root, BatteryService.getTimeRemainingText(BatteryService.primaryDevice))
        onExited: TooltipService.hide()
    }
}
