import QtQuick

// Faded divider line (adapted from Widgets/NDivider.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section).
Rectangle {
    property bool vertical: false

    width: vertical ? Style.borderS : parent.width
    height: vertical ? parent.height : Style.borderS
    gradient: Gradient {
        orientation: vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.1; color: Colors.mOutline }
        GradientStop { position: 0.9; color: Colors.mOutline }
        GradientStop { position: 1.0; color: "transparent" }
    }
}
