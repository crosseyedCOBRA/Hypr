import QtQuick

// Draggable pill chip for Settings' Bar Modules/Control Center tabs -
// represents one module in a reorderable list. Doesn't do its own drag
// tracking (see the tab's own header comment in Settings.qml for why: a
// shared ghost-follows-cursor overlay, not per-chip Drag/DropArea
// reparenting, which risks fighting the owning Repeater's own child
// management) - `pressed`/`positionChanged`/`released` just report raw
// mouse events up to whatever's listening, in the pressed item's own
// parent coordinate space (`mapToItem`-friendly) rather than trying to
// own any drag state itself.
Rectangle {
    id: chip

    required property string moduleId
    required property string label
    property bool dimmed: false

    signal chipPressed(real windowX, real windowY)
    signal chipPositionChanged(real windowX, real windowY)
    signal chipReleased(real windowX, real windowY)
    signal removeClicked()

    implicitWidth: rowLayout.implicitWidth + 16
    implicitHeight: 30
    radius: height / 2
    color: Colors.pill
    opacity: chip.dimmed ? 0.35 : 1.0

    Row {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4
        leftPadding: 10
        rightPadding: 6

        NText {
            text: chip.label
            color: Colors.text
            pointSize: Style.fontSizeS
            anchors.verticalCenter: parent.verticalCenter
        }

        NIconButton {
            baseSize: 18
            icon: ""
            anchors.verticalCenter: parent.verticalCenter
            onClicked: chip.removeClicked()
        }
    }

    MouseArea {
        id: dragArea
        // Only the label/background area starts a drag - the remove
        // button above needs its own unshadowed click, so this excludes
        // it rather than covering the whole chip.
        x: 0
        y: 0
        width: rowLayout.x + rowLayout.width - 22
        height: parent.height

        onPressed: mouse => {
            const p = mapToItem(null, mouse.x, mouse.y)
            chip.chipPressed(p.x, p.y)
        }
        onPositionChanged: mouse => {
            const p = mapToItem(null, mouse.x, mouse.y)
            chip.chipPositionChanged(p.x, p.y)
        }
        onReleased: mouse => {
            const p = mapToItem(null, mouse.x, mouse.y)
            chip.chipReleased(p.x, p.y)
        }
    }
}
