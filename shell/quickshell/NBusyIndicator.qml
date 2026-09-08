import QtQuick

// GPU-friendly spinner: a static arc drawn once on a Canvas, then rotated
// via a cheap GPU transform rather than repainting every frame (adapted
// from Widgets/NBusyIndicator.qml, MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section).
Item {
    id: root

    property bool running: true
    property color color: Colors.mPrimary
    property int size: Style.baseWidgetSize
    property int strokeWidth: Style.borderL
    property int duration: Style.animationSlow * 2

    implicitWidth: size
    implicitHeight: size

    onColorChanged: canvas.requestPaint()

    Item {
        id: spinner
        anchors.fill: parent

        Canvas {
            id: canvas
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            renderTarget: Canvas.FramebufferObject

            layer.enabled: true
            layer.smooth: true

            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var centerX = width / 2
                var centerY = height / 2
                var radius = Math.min(width, height) / 2 - strokeWidth / 2

                ctx.strokeStyle = root.color
                ctx.lineWidth = Math.max(1, root.strokeWidth)
                ctx.lineCap = "round"

                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 1.5)
                ctx.stroke()
            }
        }

        RotationAnimation on rotation {
            running: root.running
            from: 0
            to: 360
            duration: root.duration
            loops: Animation.Infinite
        }
    }
}
