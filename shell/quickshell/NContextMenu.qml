import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Popup-based context menu for use inside panels/dialogs - takes a model of
// {label, action, icon?, enabled?, visible?} items and emits `triggered`
// with the chosen action string (adapted from Widgets/NContextMenu.qml,
// MIT licensed, v4.7.7 - see README.md's "Third-party code" section).
//
// Usage:
//   NContextMenu {
//     id: contextMenu
//     parent: Overlay.overlay
//     model: [
//       { "label": "Pin to Dock", "action": "pin" },
//       { "label": "Remove", "action": "remove" }
//     ]
//     onTriggered: action => { ... }
//   }
//   MouseArea {
//     acceptedButtons: Qt.RightButton
//     onClicked: mouse => contextMenu.openAtItem(parent, mouse.x, mouse.y)
//   }
//
// Uses a plain `ListView` for its item list rather than introducing a
// dependency on the still-unported `NListView.qml` (its custom scrollbar
// policy/reserve-space props aren't needed for a short menu list) - a real
// widget only if a use case needs it.
Popup {
    id: root

    property var model: []
    property real itemHeight: 36
    property real itemPadding: Style.marginM
    // Optional: explicit item whose bounds the menu must stay within. When
    // unset, openAtItem auto-detects the nearest clipping ancestor.
    property Item constrainTo: null
    property Item _detectedConstraint: null

    signal triggered(string action)

    // Filter out hidden items to avoid spacing artifacts from zero-height items.
    readonly property var filteredModel: {
        if (!model || model.length === 0)
            return []
        const filtered = []
        for (let i = 0; i < model.length; i++) {
            if (model[i].visible !== false)
                filtered.push(model[i])
        }
        return filtered
    }

    width: 180
    padding: Style.marginS

    background: Rectangle {
        color: Colors.mSurfaceVariant
        border.color: Colors.mOutline
        border.width: Style.borderS
        radius: Style.iRadiusM
    }

    contentItem: ListView {
        id: listView
        implicitHeight: Math.max(contentHeight, root.itemHeight)
        spacing: Style.marginXXS
        interactive: contentHeight > root.height
        clip: true
        model: root.filteredModel

        delegate: ItemDelegate {
            id: menuItem
            required property var modelData
            required property int index
            width: listView.width
            height: root.itemHeight
            opacity: modelData.enabled !== false ? 1.0 : 0.5
            enabled: modelData.enabled !== false

            property var popup: root

            background: Rectangle {
                color: menuItem.hovered && menuItem.enabled ? Colors.mHover : "transparent"
                radius: Style.iRadiusS

                Behavior on color {
                    ColorAnimation { duration: Style.animationFast }
                }
            }

            contentItem: RowLayout {
                spacing: Style.marginS

                NIcon {
                    visible: menuItem.modelData.icon !== undefined
                    icon: menuItem.modelData.icon || ""
                    pointSize: Style.fontSizeM
                    color: menuItem.hovered && menuItem.enabled ? Colors.mOnHover : Colors.mOnSurface
                    Layout.leftMargin: root.itemPadding

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }
                }

                NText {
                    text: menuItem.modelData.label || menuItem.modelData.text || ""
                    pointSize: Style.fontSizeM
                    color: menuItem.hovered && menuItem.enabled ? Colors.mOnHover : Colors.mOnSurface
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillWidth: true
                    Layout.leftMargin: menuItem.modelData.icon === undefined ? root.itemPadding : 0

                    Behavior on color {
                        ColorAnimation { duration: Style.animationFast }
                    }
                }
            }

            onClicked: {
                if (enabled) {
                    popup.triggered(modelData.action || modelData.key || index.toString())
                    popup.close()
                }
            }
        }
    }

    // Opens at an absolute position within root.parent, clamped to stay
    // fully within `constrainTo` (or the nearest auto-detected clipping
    // ancestor) if one is set.
    function openAt(x, y) {
        if (root.parent) {
            const menuWidth = root.width
            const itemCount = root.filteredModel.length
            const menuHeight = Math.max(itemCount * root.itemHeight + Math.max(0, itemCount - 1) * listView.spacing, root.itemHeight) + root.topPadding + root.bottomPadding
            const constraint = root.constrainTo || root._detectedConstraint
            if (constraint) {
                const tl = constraint.mapToItem(root.parent, 0, 0)
                x = Math.max(tl.x, Math.min(x, tl.x + constraint.width - menuWidth))
                y = Math.max(tl.y, Math.min(y, tl.y + constraint.height - menuHeight))
            } else {
                x = Math.max(0, Math.min(x, root.parent.width - menuWidth))
                y = Math.max(0, Math.min(y, root.parent.height - menuHeight))
            }
        }
        root.x = x
        root.y = y
        root.open()
    }

    // Opens relative to `item`, at the given local mouse coordinates -
    // the usual entry point from a MouseArea's onClicked.
    function openAtItem(item, mouseX, mouseY) {
        if (!root.constrainTo) {
            root._detectedConstraint = null
            let p = item
            while (p && p !== root.parent) {
                if (p.clip && p.width > 0 && p.height > 0) {
                    root._detectedConstraint = p
                    break
                }
                p = p.parent
            }
        }
        const pos = item.mapToItem(root.parent, mouseX || 0, mouseY || 0)
        openAt(pos.x, pos.y)
    }
}
