import QtQuick

// Shared content for both of Dock.qml's window variants (reserved
// PanelWindow, floating FloatingWindow), and every per-monitor instance of
// either - the icon strip's layout axis (DockConfig.isVertical) and the
// launcher icon's position within it (DockConfig.launcherPosition) would
// otherwise need duplicating across all of those. Four explicit Row/Column
// variants (rather than one clever reordering trick) since stock QtQuick
// Row/Column always lay out children in their declared order - there's no
// generic "reorder a positioner's children" property to bind against, and
// four short, obviously-correct blocks read easier than indirection that
// tries to fake one.
Item {
    id: root

    property var model: []
    signal activateRequested(string windowId)
    signal launchRequested(var entry)
    signal reorderRequested(string appId, int newIndex)

    readonly property int layoutKey: (DockConfig.isVertical ? 2 : 0) + (DockConfig.launcherPosition === "end" ? 1 : 0)

    implicitWidth: layoutLoader.item ? layoutLoader.item.implicitWidth : 0
    implicitHeight: layoutLoader.item ? layoutLoader.item.implicitHeight : 0

    Loader {
        id: layoutLoader
        anchors.centerIn: parent
        sourceComponent: [rowStart, rowEnd, colStart, colEnd][root.layoutKey]
    }

    Component {
        id: rowStart
        Row {
            spacing: 10
            DockLauncherIcon {}
            DockIcons {
                model: root.model
                onActivateRequested: root.activateRequested(windowId)
                onLaunchRequested: root.launchRequested(entry)
                onReorderRequested: root.reorderRequested(appId, newIndex)
            }
        }
    }

    Component {
        id: rowEnd
        Row {
            spacing: 10
            DockIcons {
                model: root.model
                onActivateRequested: root.activateRequested(windowId)
                onLaunchRequested: root.launchRequested(entry)
                onReorderRequested: root.reorderRequested(appId, newIndex)
            }
            DockLauncherIcon {}
        }
    }

    Component {
        id: colStart
        Column {
            spacing: 10
            DockLauncherIcon {}
            DockIcons {
                vertical: true
                model: root.model
                onActivateRequested: root.activateRequested(windowId)
                onLaunchRequested: root.launchRequested(entry)
                onReorderRequested: root.reorderRequested(appId, newIndex)
            }
        }
    }

    Component {
        id: colEnd
        Column {
            spacing: 10
            DockIcons {
                vertical: true
                model: root.model
                onActivateRequested: root.activateRequested(windowId)
                onLaunchRequested: root.launchRequested(entry)
                onReorderRequested: root.reorderRequested(appId, newIndex)
            }
            DockLauncherIcon {}
        }
    }
}
