import QtQuick
import Quickshell

// The Control Center launcher icon, its own file since Bar.qml now uses it
// identically in both of its layouts (BarConfig.layoutMode "statusbar" and
// "taskbar" - see Bar.qml's own layout comment) rather than duplicating it
// between them. `barPanel`/`barSurfaceItem` are passed in explicitly since
// this is a separate file rather than a nested Component closing over
// Bar.qml's own `panel`/`barSurface` ids.
//
// Used to be a "..." chevron hidden whenever nothing was tray-enabled (back
// when Control Center was just the old flat hidden-tray flyout). Now always
// visible: the panel always has real content regardless of any one
// module's tray setting (the profile header, toggle grid, quick-launch
// tiles, and audio section aren't tray-gated at all).
//
// The source asset itself is 347x304, not truly square -
// `PreserveAspectFit` into a square box was letterboxing it (real empty
// space top and bottom, not a distortion), reading as "smushed" next to
// the bar's other icons. `PreserveAspectCrop` fills the box completely
// instead, cropping a sliver off the wider left/right edges rather than
// leaving vertical gaps - a truer square.
Image {
    id: root

    required property var barPanel
    required property Item barSurfaceItem

    source: "file://" + BarConfig.controlCenterIcon
    width: 26
    height: 26
    // Without this, a large custom user image gets decoded at full
    // native resolution and minified by the GPU at render time, which
    // reads as visibly pixelated - reported live specifically on a
    // circular custom image here. See Bar.qml's own launcher icon Image
    // for the fuller explanation - same fix, same reasoning.
    sourceSize.width: 52
    sourceSize.height: 52
    fillMode: Image.PreserveAspectCrop

    MouseArea {
        anchors.fill: parent
        onClicked: {
            ControlCenterState.panel = root.barPanel
            // barSurfaceItem (the full-width bar background, not this
            // icon) is what Settings.qml anchors under - centering it
            // under the whole bar rather than off to one side.
            ControlCenterState.barItem = root.barSurfaceItem
            ControlCenterState.visible = !ControlCenterState.visible
        }
    }
}
