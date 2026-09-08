import QtQuick

// Rounded group container (adapted from Widgets/NBox.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section). Dropped their
// smartAlpha translucency helper (tied to a global "translucent widgets"
// setting Zaris doesn't have) - always opaque here.
Item {
    id: root

    property color color: Colors.mSurfaceVariant
    property alias radius: bg.radius
    property alias border: bg.border

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Style.radiusM
        border.color: Colors.mOutline
        border.width: Style.borderS
        color: root.color
    }
}
