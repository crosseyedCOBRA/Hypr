import QtQuick

// Small dot indicating a setting differs from its default, with a hover
// tooltip (adapted from Widgets/NSettingsIndicator.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section). The tooltip itself
// is stripped - Zaris has no tooltip system yet (their TooltipService pulls
// in a whole popup-positioning stack; worth its own dedicated pass rather
// than bringing in as a side effect of one small indicator dot), so this
// just shows/hides the dot without a hover popup for now.
Rectangle {
    id: root

    property bool show: false
    property var tooltipText

    implicitWidth: show ? 6 : 0
    implicitHeight: show ? 6 : 0
    width: show ? 6 : 0
    height: show ? 6 : 0
    radius: width / 2
    color: Colors.mOnSurfaceVariant
    opacity: 0.6
    visible: show

    Behavior on opacity {
        NumberAnimation { duration: Style.animationFast }
    }
}
