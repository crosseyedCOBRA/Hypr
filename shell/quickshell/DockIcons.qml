import QtQuick
import Quickshell
import Quickshell.Widgets

// The icon row itself, shared between Dock.qml's "reserved" (PanelWindow)
// and "floating" (FloatingWindow) variants -- only one of those is ever
// visible at a time (see Dock.qml), but both host one of these.
//
// `model` is a flat list Dock.qml computes, each item shaped like:
//   { id, name, icon, pinned, running, windowIds: [...], entry }
// `entry` is the matching DesktopEntries object (for `.execute()`), or null
// for a running app with no matching installed .desktop file.
//
// A plain `Row`/`Column` can't support drag-to-reorder (a Positioner keeps
// forcibly resetting its children's x/y every relayout, fighting a
// MouseArea's own drag.target), so this manually positions each icon by
// index instead -- only pinned icons are draggable, and only ever among the
// other pinned icons (which always sit first in `model`, before any
// running-only ones) - dragging one into the running section wouldn't mean
// anything.
//
// `vertical` switches the whole layout axis (position along y instead of x,
// drag.axis YAxis instead of XAxis, implicitHeight/implicitWidth swapped) -
// for a left/right-positioned dock (Dock.qml/DockConfig.position), which
// lays its icons out top-to-bottom instead of left-to-right.
Item {
    id: root

    // Overridable (not readonly) so the bar's embedded taskbar-mode strip
    // (Bar.qml) can size icons to fit BarConfig.height instead of the
    // standalone dock's fixed 44px - both still share this exact component.
    property int iconSize: 44
    readonly property int spacing: 10

    property var model: []
    property bool vertical: false
    readonly property int pinnedCount: model.filter(function (m) { return m.pinned }).length

    implicitWidth: vertical ? iconSize : Math.max(model.length * (iconSize + spacing) - spacing, 0)
    implicitHeight: vertical ? Math.max(model.length * (iconSize + spacing) - spacing, 0) : iconSize

    signal activateRequested(string windowId)
    signal launchRequested(var entry)
    signal reorderRequested(string appId, int newIndex)

    Repeater {
        model: root.model

        Item {
            id: iconItem
            required property var modelData
            required property int index

            width: root.iconSize
            height: root.iconSize
            x: root.vertical ? 0 : index * (root.iconSize + root.spacing)
            y: root.vertical ? index * (root.iconSize + root.spacing) : 0
            z: dragArea.drag.active ? 10 : 1

            Behavior on x {
                enabled: !dragArea.drag.active
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !dragArea.drag.active
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: iconBg
                anchors.fill: parent
                radius: 8
                color: hoverArea.containsMouse || dragArea.drag.active ? Colors.pillActive : "transparent"
            }

            Loader {
                anchors.centerIn: parent
                width: 32
                height: 32
                sourceComponent: iconItem.modelData.icon ? iconImageComponent : fallbackComponent
            }

            Component {
                id: iconImageComponent
                IconImage {
                    width: 32
                    height: 32
                    source: Quickshell.iconPath(iconItem.modelData.icon, true)
                }
            }

            Component {
                id: fallbackComponent
                Rectangle {
                    width: 32
                    height: 32
                    radius: 6
                    color: Colors.pill

                    NText {
                        anchors.centerIn: parent
                        text: (iconItem.modelData.name || "?").charAt(0).toUpperCase()
                        color: Colors.text
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                    }
                }
            }

            // running indicator - sits on whichever edge is "outward" from
            // the icon strip's own layout axis (bottom for a horizontal
            // dock, right edge for a vertical one), matching where a
            // running-app dot conventionally reads as attached to the dock
            // itself rather than floating in the middle of the icon.
            Rectangle {
                visible: iconItem.modelData.running
                width: 5
                height: 5
                radius: 2.5
                color: Colors.teal
                anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
                anchors.bottom: root.vertical ? undefined : parent.bottom
                anchors.right: root.vertical ? parent.right : undefined
                anchors.bottomMargin: root.vertical ? 0 : 1
                anchors.rightMargin: root.vertical ? 1 : 0
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                z: -1
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // Only pinned icons can be dragged, and only within the
                // pinned range - root.pinnedCount - 1 is the last pinned
                // icon's slot, since pinned entries always come first.
                drag.target: iconItem.modelData.pinned ? iconItem : undefined
                drag.axis: root.vertical ? Drag.YAxis : Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: root.vertical ? 0 : Math.max(0, root.pinnedCount - 1) * (root.iconSize + root.spacing)
                drag.minimumY: 0
                drag.maximumY: root.vertical ? Math.max(0, root.pinnedCount - 1) * (root.iconSize + root.spacing) : 0

                property bool wasDragged: false

                onPressed: wasDragged = false
                onPositionChanged: function (mouse) {
                    if (drag.active)
                        wasDragged = true
                }

                onReleased: {
                    if (!drag.active && !wasDragged)
                        return
                    if (iconItem.modelData.pinned) {
                        const newIndex = Math.round((root.vertical ? iconItem.y : iconItem.x) / (root.iconSize + root.spacing))
                        root.reorderRequested(iconItem.modelData.id, newIndex)
                    }
                }

                onClicked: function (mouse) {
                    if (wasDragged)
                        return
                    if (mouse.button === Qt.RightButton) {
                        PinDialogState.open(iconItem.modelData.id, iconItem.modelData.name, iconItem.modelData.icon)
                        return
                    }
                    if (iconItem.modelData.windowIds && iconItem.modelData.windowIds.length > 0) {
                        root.activateRequested(iconItem.modelData.windowIds[0])
                    } else if (iconItem.modelData.entry) {
                        root.launchRequested(iconItem.modelData.entry)
                    }
                }
            }
        }
    }
}
