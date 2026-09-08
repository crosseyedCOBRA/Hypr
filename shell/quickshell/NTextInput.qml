import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Labeled text field with a clear button and a focus-ring border (adapted
// from Widgets/NTextInput.qml, MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section). Stripped of `Settings.data.ui.fontDefault`
// (no per-user font-family setting here, same simplification already made
// for NText/Tooltip - uses the system default font) and `I18n.tr(...)`
// calls (flattened to plain English literals, no I18n system here).
ColumnLayout {
    id: root

    property string label: ""
    property string description: ""
    property string inputIconName: ""
    property bool readOnly: false
    property color labelColor: Colors.mOnSurface
    property color descriptionColor: Colors.mOnSurfaceVariant
    property real fontSize: Style.fontSizeS
    property int fontWeight: Style.fontWeightRegular
    property var defaultValue: undefined
    property real radius: Style.iRadiusM
    property real minimumInputWidth: 80
    property bool showClearButton: true

    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputMethodHints: input.inputMethodHints
    property alias horizontalAlignment: input.horizontalAlignment
    property alias inputItem: input

    signal editingFinished
    signal accepted

    opacity: enabled ? 1.0 : 0.3
    spacing: Style.marginS

    readonly property bool isValueChanged: (defaultValue !== undefined) && (text !== defaultValue)
    readonly property string indicatorTooltip: defaultValue !== undefined ? "Default: " + (defaultValue === "" ? "(empty)" : String(defaultValue)) : ""

    NLabel {
        label: root.label
        description: root.description
        labelColor: root.labelColor
        descriptionColor: root.descriptionColor
        visible: root.label !== "" || root.description !== ""
        Layout.fillWidth: true
        showIndicator: root.isValueChanged
        indicatorTooltip: root.indicatorTooltip
    }

    // An active control that blocks input, to avoid events leaking through
    // and dragging stuff in the background.
    Control {
        id: frameControl

        Layout.fillWidth: true
        Layout.minimumWidth: root.minimumInputWidth
        Layout.margins: Style.borderS
        implicitHeight: Style.baseWidgetSize * 1.1

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        background: Rectangle {
            radius: root.radius
            color: Colors.mSurface
            border.color: input.activeFocus ? Colors.mSecondary : Colors.mOutline
            border.width: Style.borderS

            Behavior on border.color {
                ColorAnimation { duration: Style.animationFast }
            }
        }

        contentItem: Item {
            MouseArea {
                id: backgroundCapture
                anchors.fill: parent
                z: 0
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                preventStealing: true
                propagateComposedEvents: false

                onPressed: mouse => {
                    mouse.accepted = true
                    input.forceActiveFocus()
                    const inputPos = mapToItem(inputContainer, mouse.x, mouse.y)
                    if (inputPos.x >= 0 && inputPos.x <= inputContainer.width) {
                        const textPos = inputPos.x - Style.marginM
                        if (textPos >= 0 && textPos <= input.width)
                            input.cursorPosition = input.positionAt(textPos, input.height / 2)
                    }
                }
                onReleased: mouse => { mouse.accepted = true }
                onDoubleClicked: mouse => { mouse.accepted = true; input.selectAll() }
                onPositionChanged: mouse => { mouse.accepted = true }
                onWheel: wheel => { wheel.accepted = false }
            }

            Item {
                id: inputContainer
                anchors.fill: parent
                anchors.leftMargin: Style.marginM
                anchors.rightMargin: 0
                clip: true
                z: 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    NIcon {
                        icon: root.inputIconName
                        visible: root.inputIconName !== ""
                        enabled: false
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: visible ? Style.marginS : 0
                    }

                    TextField {
                        id: input

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        verticalAlignment: TextInput.AlignVCenter

                        echoMode: TextInput.Normal
                        readOnly: root.readOnly
                        placeholderTextColor: Qt.alpha(Colors.mOnSurfaceVariant, 0.6)
                        color: enabled ? Colors.mOnSurface : Qt.alpha(Colors.mOnSurface, 0.4)

                        selectByMouse: true

                        topPadding: 0
                        bottomPadding: 0
                        leftPadding: 0
                        rightPadding: 0

                        background: null

                        font.pointSize: root.fontSize
                        font.weight: root.fontWeight

                        onEditingFinished: root.editingFinished()
                        onAccepted: root.accepted()

                        MouseArea {
                            id: textFieldMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            preventStealing: true
                            propagateComposedEvents: false
                            cursorShape: Qt.IBeamCursor

                            property int selectionStart: 0

                            onPressed: mouse => {
                                mouse.accepted = true
                                input.forceActiveFocus()
                                const pos = input.positionAt(mouse.x, mouse.y)
                                input.cursorPosition = pos
                                selectionStart = pos
                            }
                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton) {
                                    mouse.accepted = true
                                    const pos = input.positionAt(mouse.x, mouse.y)
                                    input.select(selectionStart, pos)
                                }
                            }
                            onDoubleClicked: mouse => { mouse.accepted = true; input.selectAll() }
                            onReleased: mouse => { mouse.accepted = true }
                            onWheel: wheel => { wheel.accepted = false }
                        }
                    }

                    NIconButton {
                        id: clearButton
                        icon: "" // nf-fa-times
                        tooltipText: (input.text.length > 0 && !root.readOnly && root.enabled) ? "Clear" : ""

                        Layout.alignment: Qt.AlignVCenter
                        border.width: 0

                        colorBg: "transparent"
                        colorBgHover: "transparent"
                        colorFg: Colors.mOnSurface
                        colorFgHover: Colors.mError

                        visible: root.showClearButton && input.text.length > 0 && !root.readOnly
                        enabled: input.text.length > 0 && !root.readOnly && root.enabled

                        onClicked: {
                            input.clear()
                            input.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }
}
