import QtQuick
import QtQuick.Layouts

// Section header: bold title + muted description (adapted from
// Widgets/NHeader.qml, MIT licensed, v4.7.7 - see README.md's "Third-party
// code" section).
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""
    property bool enableDescriptionRichText: false

    opacity: enabled ? 1.0 : 0.6
    spacing: Style.marginXXS
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM

    NText {
        text: root.label
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightSemiBold
        color: Colors.mPrimary
        visible: root.label !== ""
    }

    NText {
        text: root.description
        pointSize: Style.fontSizeM
        color: Colors.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        visible: root.description !== ""
        richTextEnabled: root.enableDescriptionRichText
    }
}
