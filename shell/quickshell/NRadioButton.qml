import QtQuick
import QtQuick.Controls

// Radio button with a custom ring/dot indicator (adapted from
// Widgets/NRadioButton.qml, MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section). Uses QtQuick.Controls' RadioButton purely as
// a behavioral base (checked-state/exclusivity handling) with a fully
// custom indicator/contentItem - not the same pattern flagged in past bugs
// here (an attached `ToolTip` on a `MouseArea`'s own `Item` eating its
// clicks); this doesn't attach anything to a click-handling Item.
RadioButton {
    id: root

    property real pointSize: Style.fontSizeM

    implicitWidth: outerCircle.implicitWidth + Style.marginS + contentItem.implicitWidth

    indicator: Rectangle {
        id: outerCircle

        implicitWidth: Style.baseWidgetSize * 0.625 * pointSize / Style.fontSizeM
        implicitHeight: Style.baseWidgetSize * 0.625 * pointSize / Style.fontSizeM
        radius: Math.min(Style.iRadiusL, width / 2)
        color: "transparent"
        border.color: root.checked ? Colors.mPrimary : Colors.mOnSurface
        border.width: Style.borderM
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.3

            radius: Math.min(Style.iRadiusL, width / 2)
            color: Qt.alpha(Colors.mPrimary, root.checked ? 1 : 0)

            Behavior on color {
                ColorAnimation { duration: Style.animationFast }
            }
        }

        Behavior on border.color {
            ColorAnimation { duration: Style.animationFast }
        }
    }

    contentItem: NText {
        text: root.text
        pointSize: root.pointSize
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: outerCircle.right
        anchors.right: parent.right
        anchors.leftMargin: Style.marginS
    }
}
