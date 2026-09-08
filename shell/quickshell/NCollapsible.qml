import QtQuick
import QtQuick.Layouts

// Expandable/collapsible section with a colored, clickable header (adapted
// from Widgets/NCollapsible.qml, MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section).
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""
    property bool expanded: false
    property real contentSpacing: Style.marginM
    property bool _userInteracted: false

    signal toggled(bool expanded)

    Layout.fillWidth: true
    spacing: 0

    default property alias content: contentLayout.children

    Rectangle {
        id: headerContainer
        Layout.fillWidth: true
        Layout.preferredHeight: headerContent.implicitHeight + Style.margin2M
        color: root.expanded ? Colors.mSecondary : Colors.mPrimary
        radius: Style.iRadiusM
        border.color: root.expanded ? Colors.mOnSecondary : Colors.mOutline
        border.width: Style.borderS

        Behavior on color {
            enabled: root._userInteracted
            ColorAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            enabled: root._userInteracted
            ColorAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: headerArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                root._userInteracted = true
                root.expanded = !root.expanded
                root.toggled(root.expanded)
            }

            Rectangle {
                anchors.fill: parent
                color: headerArea.containsMouse ? Colors.mOnSurface : "transparent"
                opacity: headerArea.containsMouse ? 0.08 : 0
                radius: headerContainer.radius

                Behavior on opacity {
                    NumberAnimation { duration: Style.animationFast }
                }
            }
        }

        RowLayout {
            id: headerContent
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
                id: chevronIcon
                icon: ""
                pointSize: Style.fontSizeL
                color: root.expanded ? Colors.mOnSecondary : Colors.mOnPrimary
                Layout.alignment: Qt.AlignVCenter

                rotation: root.expanded ? 90 : 0
                Behavior on rotation {
                    enabled: root._userInteracted
                    NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    enabled: root._userInteracted
                    ColorAnimation { duration: Style.animationNormal }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Style.marginL

                NText {
                    text: root.label
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightSemiBold
                    color: root.expanded ? Colors.mOnSecondary : Colors.mOnPrimary
                    wrapMode: Text.WordWrap

                    Behavior on color {
                        enabled: root._userInteracted
                        ColorAnimation { duration: Style.animationNormal }
                    }
                }

                NText {
                    text: root.description
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightRegular
                    color: root.expanded ? Colors.mOnSecondary : Colors.mOnPrimary
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    visible: root.description !== ""
                    opacity: 0.87

                    Behavior on color {
                        enabled: root._userInteracted
                        ColorAnimation { duration: Style.animationNormal }
                    }
                }
            }
        }
    }

    Rectangle {
        id: contentContainer
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS

        visible: root.expanded
        color: Colors.mSurface
        radius: Style.iRadiusL
        border.color: Colors.mOutline
        border.width: Style.borderS

        Layout.preferredHeight: expanded ? contentLayout.implicitHeight + Style.margin2L : 0

        Behavior on Layout.preferredHeight {
            enabled: root._userInteracted
            NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: root.contentSpacing
        }

        opacity: root.expanded ? 1.0 : 0.0
        Behavior on opacity {
            enabled: root._userInteracted
            NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
        }
    }
}
