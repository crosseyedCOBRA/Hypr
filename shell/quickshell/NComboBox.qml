import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Labeled dropdown, model items shaped as {key, name} (adapted from
// Widgets/NComboBox.qml, MIT licensed, v4.7.7 - see README.md's
// "Third-party code" section). Stripped of `I18n.tr(...)` calls (flattened
// to plain English literals) and the "System Default" empty-key special
// case (no per-user default-value indicator system here beyond the
// existing NSettingsIndicator, which this still supports via
// isValueChanged/indicatorTooltip). The popup's list uses a plain
// `ListView` rather than introducing a dependency on the still-unported
// `NListView.qml` (its own scroll-gradient-mask styling isn't needed for
// a single dropdown popup) - a real widget only if a use case needs it.
RowLayout {
    id: root

    property real minimumWidth: 200
    property real popupHeight: 180

    property string label: ""
    property string description: ""
    property string tooltip: ""
    property var model
    property string currentKey: ""
    property string placeholder: ""
    property var defaultValue: undefined

    readonly property real preferredHeight: Math.round(Style.baseWidgetSize * 1.1)
    readonly property var comboBox: combo

    signal selected(string key)

    spacing: Style.marginL

    // Less strict comparison with != (instead of !==) so it can properly
    // compare int vs string (e.g. for a numeric key like 30 vs "30").
    readonly property bool isValueChanged: (defaultValue !== undefined) && (currentKey != defaultValue)

    readonly property string indicatorTooltip: {
        if (defaultValue === undefined)
            return ""
        let displayValue = String(defaultValue)
        const idx = root.findIndexByKey(String(defaultValue))
        if (idx >= 0) {
            const item = root.getItem(idx)
            if (item && item.name)
                displayValue = item.name
        }
        return "Default: " + displayValue
    }

    function itemCount() {
        if (!root.model)
            return 0
        if (typeof root.model.count === 'number')
            return root.model.count
        if (Array.isArray(root.model))
            return root.model.length
        return 0
    }

    function getItem(index) {
        if (!root.model)
            return null
        if (typeof root.model.get === 'function')
            return root.model.get(index)
        if (Array.isArray(root.model))
            return root.model[index]
        return null
    }

    function findIndexByKey(key) {
        for (let i = 0; i < itemCount(); i++) {
            const item = getItem(i)
            if (item && item.key === key)
                return i
        }
        return -1
    }

    NLabel {
        label: root.label
        description: root.description
        showIndicator: root.isValueChanged
        indicatorTooltip: root.indicatorTooltip
    }

    ComboBox {
        id: combo

        opacity: enabled ? 1.0 : 0.6
        Layout.margins: Style.borderS
        Layout.minimumWidth: root.minimumWidth
        Layout.preferredHeight: root.preferredHeight
        implicitWidth: Layout.minimumWidth
        model: root.model
        textRole: "name"
        currentIndex: root.findIndexByKey(root.currentKey)

        onActivated: {
            const item = root.getItem(combo.currentIndex)
            if (item && item.key !== undefined)
                root.selected(item.key)
        }

        Keys.onUpPressed: event => {
            if (combo.popup.visible) {
                if (listView.currentIndex > 0) {
                    listView.currentIndex--
                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                }
                event.accepted = true
            } else {
                event.accepted = false
            }
        }

        Keys.onDownPressed: event => {
            if (combo.popup.visible) {
                if (listView.currentIndex < root.itemCount() - 1) {
                    listView.currentIndex++
                    listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                }
                event.accepted = true
            } else {
                event.accepted = false
            }
        }

        Keys.onReturnPressed: event => {
            if (combo.popup.visible) {
                const item = root.getItem(listView.currentIndex)
                if (item && item.key !== undefined) {
                    root.selected(item.key)
                    combo.currentIndex = listView.currentIndex
                    combo.popup.close()
                }
                event.accepted = true
            } else {
                event.accepted = false
            }
        }

        background: Rectangle {
            implicitWidth: Style.baseWidgetSize * 3.75
            implicitHeight: root.preferredHeight
            color: Colors.mSurface
            border.color: combo.activeFocus ? Colors.mSecondary : Colors.mOutline
            border.width: Style.borderS
            radius: Style.iRadiusM

            Behavior on border.color {
                ColorAnimation { duration: Style.animationFast }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    if (root.tooltip !== "")
                        TooltipService.show(root, root.tooltip)
                }
                onExited: {
                    if (root.tooltip !== "")
                        TooltipService.hide()
                }
            }
        }

        contentItem: NText {
            leftPadding: Style.marginL
            rightPadding: combo.indicator.width + Style.marginL
            pointSize: Style.fontSizeM
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: combo.currentIndex >= 0 ? Colors.mOnSurface : Colors.mOnSurfaceVariant
            text: {
                if (combo.currentIndex >= 0 && combo.currentIndex < root.itemCount()) {
                    const item = root.getItem(combo.currentIndex)
                    return item ? item.name : root.placeholder
                }
                return root.placeholder
            }
        }

        indicator: NIcon {
            x: combo.width - width - Style.marginM
            y: combo.topPadding + (combo.availableHeight - height) / 2
            icon: ""
            pointSize: Style.fontSizeL
        }

        popup: Popup {
            y: combo.height + Style.marginS
            implicitWidth: combo.width
            implicitHeight: Math.min(root.popupHeight, listView.contentHeight + Style.margin2M)
            padding: Style.marginM

            onOpened: {
                listView.currentIndex = combo.currentIndex
                listView.positionViewAtIndex(combo.currentIndex, ListView.Beginning)
            }

            contentItem: ListView {
                id: listView
                property var comboBox: combo
                model: combo.popup.visible ? root.model : null
                clip: true
                highlightMoveDuration: 0

                delegate: Rectangle {
                    id: delegateRect
                    required property int index
                    property bool isHighlighted: listView.currentIndex === index

                    width: listView.width
                    height: delegateText.implicitHeight + Style.margin2S
                    radius: Style.iRadiusS
                    color: isHighlighted ? Colors.mHover : "transparent"

                    NText {
                        id: delegateText
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginM
                        anchors.rightMargin: Style.marginM
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        pointSize: Style.fontSizeM
                        color: delegateRect.isHighlighted ? Colors.mOnHover : Colors.mOnSurface
                        text: {
                            const item = root.getItem(delegateRect.index)
                            return item && item.name ? item.name : ""
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onContainsMouseChanged: {
                            if (containsMouse)
                                listView.currentIndex = delegateRect.index
                        }
                        onClicked: {
                            const item = root.getItem(delegateRect.index)
                            if (item && item.key !== undefined) {
                                root.selected(item.key)
                                listView.comboBox.currentIndex = delegateRect.index
                                listView.comboBox.popup.close()
                            }
                        }
                    }
                }
            }

            background: Rectangle {
                color: Colors.mSurfaceVariant
                border.color: Colors.mOutline
                border.width: Style.borderS
                radius: Style.iRadiusM
            }
        }

        Connections {
            target: root
            function onCurrentKeyChanged() {
                combo.currentIndex = root.findIndexByKey(root.currentKey)
            }
            function onModelChanged() {
                combo.currentIndex = root.findIndexByKey(root.currentKey)
            }
        }
    }
}
