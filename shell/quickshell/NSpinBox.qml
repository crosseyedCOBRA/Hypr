import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Numeric stepper with press-and-hold repeat/ramp-up and a directly
// editable value field (adapted from Widgets/NSpinBox.qml, MIT licensed,
// v4.7.7 - see README.md's "Third-party code" section). Stripped of
// `Settings.data.ui.fontFixed` (no configurable fixed-width font here,
// same simplification NText.qml already made - just uses the system
// default) and `I18n.tr(...)` (flattened to a plain English literal).
RowLayout {
    id: root

    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property string suffix: ""
    property string prefix: ""
    property string label: ""
    property string description: ""
    property bool hovering: false
    property int baseSize: Style.baseWidgetSize
    property var defaultValue: undefined

    property alias minimum: root.from
    property alias maximum: root.to

    // Press-and-hold repeat tuning
    property int initialRepeatDelay: 400   // pause after the first click (ms)
    property int repeatInterval: 80        // step interval after that pause (ms)
    property int rampFactor: 4             // ticks between step-size increases
    property int maxStepMultiplier: 10     // cap on how large the step can ramp to
    property int _holdTicks: 0
    property int _repeatDirection: 0       // -1 decrease, 1 increase

    signal entered
    signal exited

    Layout.fillWidth: true

    readonly property bool isValueChanged: (defaultValue !== undefined) && (value !== defaultValue)
    readonly property string indicatorTooltip: defaultValue !== undefined ? "Default: " + String(defaultValue) : ""

    Timer {
        id: repeatTimer
        repeat: true
        interval: root.initialRepeatDelay

        onTriggered: {
            if (repeatTimer.interval === root.initialRepeatDelay) {
                repeatTimer.interval = root.repeatInterval
                root._holdTicks = 0
            }
            root._holdTicks++
            const stepMultiplier = Math.min(root.maxStepMultiplier, 1 + Math.floor(root._holdTicks / root.rampFactor))
            changeValue(root._repeatDirection, root.stepSize * stepMultiplier)
        }
    }

    function changeValue(direction, step) {
        const currentStep = step || root.stepSize

        if (direction === 1 && root.value < root.to) {
            root.value = Math.min(root.to, root.value + currentStep)
        } else if (direction === -1 && root.value > root.from) {
            root.value = Math.max(root.from, root.value - currentStep)
        } else {
            return
        }

        if (root.value === root.to || root.value === root.from)
            stopRepeat()
    }

    function stopRepeat() {
        root._repeatDirection = 0
        repeatTimer.stop()
        repeatTimer.interval = root.initialRepeatDelay
    }

    NLabel {
        label: root.label
        description: root.description
        showIndicator: root.isValueChanged
        indicatorTooltip: root.indicatorTooltip
    }

    Rectangle {
        id: spinBoxContainer
        Layout.margins: Style.borderS
        implicitWidth: 120
        implicitHeight: Math.round((root.baseSize - 4) / 2) * 2
        radius: Style.iRadiusS
        color: Colors.mSurfaceVariant
        border.color: (root.hovering || decreaseArea.containsMouse || increaseArea.containsMouse) ? Colors.mHover : Colors.mOutline
        border.width: Style.borderS

        Behavior on border.color {
            ColorAnimation { duration: Style.animationFast }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            onEntered: {
                if (!root.enabled)
                    return
                root.hovering = true
                root.entered()
            }
            onExited: {
                root.hovering = false
                root.exited()
            }
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0 && root.value < root.to)
                    root.value = Math.min(root.to, root.value + root.stepSize)
                else if (wheel.angleDelta.y < 0 && root.value > root.from)
                    root.value = Math.max(root.from, root.value - root.stepSize)
            }
        }

        Item {
            id: decreaseButton
            height: parent.height
            width: height
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            opacity: (root.enabled && root.value > root.from) || decreaseArea.containsMouse ? 1.0 : 0.3

            Rectangle {
                anchors.centerIn: parent
                width: parent.height
                height: width
                radius: spinBoxContainer.radius
                color: Colors.mHover
                opacity: decreaseArea.containsMouse ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: Style.animationFast }
                }
            }

            NIcon {
                anchors.centerIn: parent
                icon: ""
                pointSize: Style.fontSizeS
                color: decreaseArea.containsMouse ? Colors.mOnHover : Colors.mPrimary
            }

            MouseArea {
                id: decreaseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled && root.value > root.from
                onPressed: {
                    root._repeatDirection = -1
                    changeValue(root._repeatDirection, root.stepSize)
                    repeatTimer.start()
                }
                onReleased: stopRepeat()
                onExited: stopRepeat()
            }
        }

        Item {
            id: increaseButton
            height: parent.height
            width: height
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            opacity: (root.enabled && root.value < root.to) || increaseArea.containsMouse ? 1.0 : 0.3

            Rectangle {
                anchors.centerIn: parent
                width: parent.height
                height: width
                radius: spinBoxContainer.radius
                color: Colors.mHover
                opacity: increaseArea.containsMouse ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: Style.animationFast }
                }
            }

            NIcon {
                anchors.centerIn: parent
                icon: ""
                pointSize: Style.fontSizeS
                color: increaseArea.containsMouse ? Colors.mOnHover : Colors.mPrimary
            }

            MouseArea {
                id: increaseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled && root.value < root.to
                onPressed: {
                    root._repeatDirection = 1
                    changeValue(root._repeatDirection, root.stepSize)
                    repeatTimer.start()
                }
                onReleased: stopRepeat()
                onExited: stopRepeat()
            }
        }

        Item {
            id: valueContainer
            anchors.left: decreaseButton.right
            anchors.right: increaseButton.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 4
            height: parent.height

            RowLayout {
                anchors.centerIn: parent
                spacing: 0

                NText {
                    text: root.prefix
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightMedium
                    color: Qt.alpha(Colors.mOnSurface, root.enabled ? 1.0 : 0.6)
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.prefix !== ""
                }

                TextInput {
                    id: valueInput
                    text: valueInput.focus ? valueInput.text : root.value.toString()
                    font.pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightMedium
                    color: Qt.alpha(Colors.mOnSurface, root.enabled ? 1.0 : 0.6)
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                    selectByMouse: true
                    enabled: root.enabled

                    validator: IntValidator {
                        bottom: root.from
                        top: root.to
                    }

                    onAccepted: {
                        applyValue()
                        focus = false
                    }

                    Keys.onEscapePressed: {
                        text = root.value.toString()
                        focus = false
                    }

                    onFocusChanged: {
                        if (focus)
                            selectAll()
                        else
                            applyValue()
                    }

                    function applyValue() {
                        let newValue = parseInt(text)
                        if (!isNaN(newValue)) {
                            newValue = Math.max(root.from, Math.min(root.to, newValue))
                            root.value = newValue
                        }
                    }
                }

                NText {
                    text: root.suffix
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightMedium
                    color: Qt.alpha(Colors.mOnSurface, root.enabled ? 1.0 : 0.6)
                    verticalAlignment: Text.AlignVCenter
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.suffix !== ""
                }
            }
        }
    }
}
