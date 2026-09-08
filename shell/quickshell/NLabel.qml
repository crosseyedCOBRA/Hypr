import QtQuick
import QtQuick.Layouts

// Icon + label + description block, used as the prefix on most settings
// rows (adapted from Widgets/NLabel.qml, MIT licensed, v4.7.7 - see
// README.md's "Third-party code" section).
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""
    property string icon: ""
    property color labelColor: Colors.mOnSurface
    property color descriptionColor: Colors.mOnSurfaceVariant
    property color iconColor: Colors.mOnSurface
    property bool showIndicator: false
    property string indicatorTooltip: ""
    property real labelSize: Style.fontSizeL

    opacity: enabled ? 1.0 : 0.6
    spacing: Style.marginXXS
    visible: root.label !== "" || root.description !== ""

    Layout.fillWidth: true

    RowLayout {
        spacing: Style.marginXS
        Layout.fillWidth: true
        visible: root.label !== ""

        NIcon {
            visible: root.icon !== ""
            icon: root.icon
            pointSize: Style.fontSizeXXL
            color: root.iconColor
            Layout.rightMargin: Style.marginS
        }

        NText {
            id: labelText
            Layout.fillWidth: true
            text: root.label
            pointSize: root.labelSize
            font.weight: Style.fontWeightSemiBold
            color: root.labelColor
            wrapMode: Text.WordWrap

            Loader {
                active: root.showIndicator
                x: labelText.contentWidth + Style.marginXS
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: NSettingsIndicator {
                    show: true
                    tooltipText: root.indicatorTooltip || ""
                }
            }
        }
    }

    NText {
        visible: root.description !== ""
        Layout.fillWidth: true
        text: root.description
        pointSize: Style.fontSizeS
        color: root.descriptionColor
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
    }
}
