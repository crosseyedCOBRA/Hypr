import QtQuick
import QtQuick.Layouts

// Labeled checkbox (adapted from Widgets/NCheckbox.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section).
RowLayout {
    id: root

    property string label: ""
    property string description: ""
    property bool checked: false
    property bool hovering: false
    property color activeColor: Colors.mPrimary
    property color activeOnColor: Colors.mOnPrimary
    property int baseSize: root.defaultSize
    property real labelSize: Style.fontSizeL

    readonly property int defaultSize: Style.baseWidgetSize * 0.7

    signal toggled(bool checked)
    signal entered
    signal exited

    Layout.fillWidth: true

    NLabel {
        label: root.label
        labelSize: root.labelSize
        description: root.description
        visible: root.label !== "" || root.description !== ""
    }

    Item { Layout.fillWidth: true }

    Rectangle {
        id: box

        opacity: enabled ? 1.0 : 0.6
        Layout.margins: Style.borderS
        implicitWidth: Style.toOdd(root.baseSize)
        implicitHeight: Style.toOdd(root.baseSize)
        radius: Style.iRadiusXS * (root.baseSize / root.defaultSize)
        color: root.checked ? root.activeColor : Colors.mSurface
        border.color: Colors.mOutline
        border.width: Style.borderS

        Behavior on color {
            ColorAnimation { duration: Style.animationFast }
        }

        Behavior on border.color {
            ColorAnimation { duration: Style.animationFast }
        }

        NIcon {
            visible: root.checked
            x: Style.pixelAlignCenter(parent.width, width)
            y: Style.pixelAlignCenter(parent.height, height)
            icon: ""
            color: root.activeOnColor
            pointSize: Style.toOdd(root.baseSize * 0.5)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: {
                hovering = true
                root.entered()
            }
            onExited: {
                hovering = false
                root.exited()
            }
            onClicked: root.toggled(!root.checked)
        }
    }
}
