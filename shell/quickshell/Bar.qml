import QtQuick
import Quickshell

// One panel per monitor. Systray/kernel/network are only shown on the
// primary monitor -- no point duplicating that info across every screen.
//
// Mirrored outputs (e.g. `xrandr --output HDMI-A-0 --same-as DisplayPort-0`)
// still show up as two distinct entries in Quickshell.screens, each with
// identical geometry - without deduplicating them here, a second, fully
// overlapping bar gets created on top of the real one for every mirrored
// screen, hiding its tray/kernel modules behind whichever bar happens to
// stack on top. Collapsing to one bar per unique geometry, keeping the
// first occurrence of each, fixes this while leaving true multi-monitor
// (distinct positions) completely unaffected - and keeps `isPrimary` below
// correct too, since the survivor for the first geometry is always the
// literal `Quickshell.screens[0]` object.
//
// BarConfig.layoutMode picks between two very different arrangements,
// switched via a Loader (same "two explicit layouts read easier than
// indirection that fakes one" reasoning DockContent.qml already
// established for its four position/launcher-position variants):
//
//   "statusbar" (BarConfig.layoutMode default, the original layout): logo
//   + workspaces on the left, the clock centered, status modules + Control
//   Center on the right. A separate standalone Dock (Dock.qml), if the
//   user enables it, is the only place pinned/running apps show up.
//
//   "taskbar": a Plasma/Windows-style layout - launcher icon + an app strip
//   (DockItemsService.dockItems, the exact same pinned+running data the
//   standalone dock itself uses) embedded directly in the bar on the left,
//   workspaces centered, and status modules + clock + Control Center on
//   the right. Dock.qml suppresses its own windows entirely while this is
//   active (see its own comment) - the embedded strip replaces it rather
//   than the two coexisting. The launcher icon here also sets
//   LauncherState.anchorItem, so Launcher.qml's taskbar-mode PopupWindow
//   variant opens anchored right under/above it instead of centered on
//   screen - see Launcher.qml's own comment.
//
// BarConfig.position (top/bottom) and the background opacity/height below
// apply identically regardless of which layout is active.
//
// Both layout Components and the PanelWindow live inside one wrapping Item
// per monitor (barDelegate) - Variants only accepts a single delegate, the
// same reason Dock.qml wraps its own two window variants in one Item too.
Variants {
    model: {
        const seen = []
        const result = []
        for (const s of Quickshell.screens) {
            const key = s.x + "," + s.y + "," + s.width + "," + s.height
            if (seen.includes(key))
                continue
            seen.push(key)
            result.push(s)
        }
        return result
    }

    Item {
        id: barDelegate
        required property var modelData
        readonly property bool isPrimary: barDelegate.modelData === Quickshell.screens[0]

        PanelWindow {
            id: panel
            readonly property bool isPrimary: barDelegate.isPrimary

            screen: barDelegate.modelData

            anchors.top: BarConfig.position === "top"
            anchors.bottom: BarConfig.position === "bottom"
            anchors.left: true
            anchors.right: true

            implicitHeight: BarConfig.height
            exclusiveZone: BarConfig.height
            color: "transparent"

            // No margin/radius here - the WM now shape-masks dock-type
            // windows for real rounding (see applyShapeToWindow in
            // windowManager.cpp), so this fills the window's actual shape
            // edge to edge (a full-width bar with just its four corners
            // rounded) rather than approximating rounding with its own
            // inset+radius, which (with no compositor to blend alpha)
            // rendered as an opaque black square peeking out around the
            // edges instead of true transparency.
            Rectangle {
                id: barSurface
                anchors.fill: parent
                // Colors.barBg (ThemeConfig.barBackground, falling back to
                // the same Colors.bg every other panel uses when unset) at
                // BarConfig.backgroundOpacity alpha - was a hardcoded
                // literal matching Colors.bg's own then-fixed default, only
                // ever an approximation by convention rather than a real
                // binding. Genuinely wrong once Colors.bg became
                // user-themeable (ThemeConfig.qml/Settings' Colors tab) -
                // a palette change silently wouldn't have reached the bar
                // at all otherwise, unlike every other Colors.bg consumer.
                // Switched from Colors.bg directly to Colors.barBg once a
                // separate bar-color override existed (Settings' Colors
                // tab) - see Colors.qml's own comment.
                color: {
                    const c = Qt.color(Colors.barBg)
                    return Qt.rgba(c.r, c.g, c.b, BarConfig.backgroundOpacity)
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    Loader {
                        anchors.fill: parent
                        sourceComponent: BarConfig.layoutMode === "taskbar" ? taskbarLayout : statusBarLayout
                    }
                }
            }
        }

        // ==================== "statusbar" layout ====================
        Component {
            id: statusBarLayout
            Item {
                anchors.fill: parent

                // --- left: logo + workspaces, then any left-assigned modules ---
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            source: "file://" + BarConfig.launcherIcon
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                onClicked: LauncherState.visible = !LauncherState.visible
                            }
                        }

                        Workspaces {
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    BarStatusModules {
                        barPanel: panel
                        section: "left"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // --- center: clock, then any center-assigned modules ---
                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    BarClockText {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarStatusModules {
                        barPanel: panel
                        section: "center"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // --- right: system status + Control Center ---
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    BarStatusModules {
                        barPanel: panel
                        section: "right"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarControlCenterLauncher {
                        barPanel: panel
                        barSurfaceItem: barSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ==================== "taskbar" layout ====================
        Component {
            id: taskbarLayout
            Item {
                anchors.fill: parent

                // --- left: launcher + embedded dock ---
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Image {
                        id: taskbarLauncherIcon
                        source: "file://" + BarConfig.launcherIcon
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                LauncherState.anchorItem = taskbarLauncherIcon
                                LauncherState.visible = !LauncherState.visible
                            }
                        }
                    }

                    DockIcons {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: Math.max(20, Math.min(BarConfig.height - 12, 40))
                        model: DockItemsService.dockItems
                        onActivateRequested: DockItemsService.activate(windowId)
                        onLaunchRequested: entry.execute()
                        onReorderRequested: DockConfig.reorderPinned(appId, newIndex)
                    }
                }

                // --- center: workspaces ---
                Workspaces {
                    anchors.centerIn: parent
                }

                // --- right: system status + clock + Control Center ---
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    BarStatusModules {
                        barPanel: panel
                        section: "right"
                        anySection: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarClockText {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BarControlCenterLauncher {
                        barPanel: panel
                        barSurfaceItem: barSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
