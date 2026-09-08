import QtQuick

// Compact radial gauge (ring + centered value + icon below), for the
// Control Center's system-stats cluster - matches the small circular
// readouts (battery/temp/load) in Noctalia's own Control Center reference
// screenshot. Canvas-based rather than QtQuick.Shapes/PathArc (the
// technique NSlider.qml already uses for its own custom-drawn track) -
// a percentage-arc is much simpler to get right via Canvas's own
// context.arc(cx, cy, r, startAngle, endAngle) than hand-deriving PathArc
// endpoint coordinates from a percentage.
Item {
    id: root

    property real value: 0 // 0.0 - 1.0, clamped when drawn
    property string valueText: ""
    property string icon: ""
    property color trackColor: Colors.pill
    property color fillColor: Colors.blue
    property color iconColor: Colors.textMuted
    property real diameter: 46
    property real lineWidth: 5

    implicitWidth: diameter
    implicitHeight: diameter + (icon !== "" ? 16 : 0)

    Canvas {
        id: canvas
        width: root.diameter
        height: root.diameter
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const cx = width / 2
            const cy = height / 2
            const r = (width - root.lineWidth) / 2
            const startAngle = -Math.PI / 2
            const ratio = Math.max(0, Math.min(1, root.value))

            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = root.trackColor
            ctx.stroke()

            if (ratio > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, startAngle + Math.PI * 2 * ratio)
                ctx.strokeStyle = root.fillColor
                ctx.stroke()
            }
        }

        Connections {
            target: root
            function onValueChanged() { canvas.requestPaint() }
            function onFillColorChanged() { canvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }

    NText {
        anchors.centerIn: canvas
        text: root.valueText
        color: Colors.text
        pointSize: Style.fontSizeXXS
        font.weight: Style.fontWeightBold
    }

    NIcon {
        visible: root.icon !== ""
        icon: root.icon
        color: root.iconColor
        pointSize: Style.fontSizeXS
        anchors.top: canvas.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
