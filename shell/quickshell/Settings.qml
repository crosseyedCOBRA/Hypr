import QtQuick
import Quickshell

// GUI settings app: sidebar (category list) + content pane, modeled after
// Noctalia's own settings panel (a screenshot of it was the direct
// reference) rather than the single long scrolling list this used to be.
// Each category maps to something that genuinely already has settings
// today (Bar's per-module config, Dock's enabled/mode) - no placeholder
// categories for features that don't exist yet. New categories get added
// as the underlying WM/shell feature they'd configure actually exists, not
// ahead of it - the full WM config (keybinds, window rules, gaps/borders)
// still has no GUI and stays hand-edit-only in zaris.conf for now (see
// ROADMAP.md's "GUI settings app, full WM config" backlog item, which this
// is the first step of).
//
// Phase 2 of the Noctalia-port effort (see ROADMAP.md): this is the first
// existing screen rebuilt to actually use the ported widget library rather
// than the original hand-rolled Rectangle/Text pattern - the plain
// Flickable is now NScrollView (real scrollbar styling + smooth wheel
// scroll), raw Text is now NText throughout (consistent typography off
// Style.qml's tokens), and the two-Rectangle "pill pair" selectors
// (screens: All/Primary, dock mode: Reserved/Floating) are now
// NTabBar/NTabButton, a genuine behavioral and visual upgrade over the
// hand-rolled pair (proper hover states, tooltip support, shared
// segmented-control styling used the same way a future settings row would
// elsewhere). The sidebar nav list is intentionally left as its own
// pattern - it's a vertical category list, not a fit for NTabBar's
// horizontal segmented-control shape.
//
// Still writes straight through the same ModulesConfig/DockConfig
// FileViews as before - same JSON files, same live-apply behavior, just
// reorganized under a nav shell instead of one flat list.
//
// Built on PopupWindow rather than a FloatingWindow, same reasoning as
// CalendarFlyout.qml/Tooltip.qml: anchors directly to the bar's own
// full-width background surface (ControlCenterState.barItem - opened by
// clicking the gear button inside Control Center, which sets
// SettingsState.targetItem to that surface right before opening this and
// closing itself) via `anchor.item`, so it opens attached to the bar
// rather than centered on screen - needing none of Zaris's WM-side
// windowrule system, and no `title` property to match a rule against
// (PopupWindow doesn't expose one at all - positioning is entirely
// anchor-based now). Deliberately anchored to the bar surface and not the
// gear button that's actually clicked - Control Center closes at the same
// moment Settings opens, and a PopupWindow can't anchor to a target
// inside a window that's just gone invisible; the bar itself never
// closes, so it stays a valid anchor regardless of Control Center's state.
// Anchoring to the full-width surface (rather than the launcher icon
// itself, as an earlier pass did) also means the centering math below is
// centering under the whole bar, not just under a small icon near its edge.
PopupWindow {
    id: settingsWindow

    visible: SettingsState.visible && !!SettingsState.targetItem
    color: Colors.bg

    // Same override-redirect focus gap as Launcher.qml's taskbar-mode
    // popup (see its own comment for the full mechanism/investigation) -
    // confirmed live this affects Settings specifically, not just in
    // theory: without grabFocus, XGetInputFocus stays at PointerRoot
    // while this window is open, meaning keystrokes only reach it while
    // the mouse pointer happens to still be directly over it - the moment
    // the pointer drifts even slightly (trivially easy mid-typing in real
    // use), every further keystroke into any field here (icon paths,
    // display name, weather location) is silently lost. Reported live as
    // "it also does not let me type in those text boxes" - reproduced
    // exactly that way (typed text landing fine while the simulated
    // pointer stayed frozen over the field, then vanishing entirely the
    // instant the pointer moved away mid-edit, before any real fix).
    // Settings has real text entry throughout, unlike Tooltip.qml/
    // CalendarFlyout.qml, so this is unconditional here.
    grabFocus: true

    implicitWidth: 680
    // Tall enough that every category's content fits without the
    // NScrollView ever actually needing to scroll - the Defaults tab (six
    // Default-app dropdowns plus a Screenshot folder field, added on top
    // of the existing icon/cursor/font theming) is now the tallest,
    // confirmed live in a Xephyr sandbox iteratively (each bump/trim
    // re-verified against a real screenshot, not calculated blind).
    // Reclaimed real space first rather than just growing the window -
    // six repeated two-line "applies immediately" descriptions collapsed
    // into one shared note above the group, the Screenshot folder row's
    // own description trimmed to one line, and the long icon/cursor/font
    // restart-note paragraph at the bottom reworded shorter without
    // losing any of its actual content - only grew implicitHeight once
    // those savings alone still weren't enough. 1040 is a few px past the
    // theoretical safe ceiling (974px: a bar-position-aware popup,
    // BarConfig.popupAnchorY, opening upward above a bottom-positioned
    // bar at its maximum configurable height - 96px, the default is 44px
    // - on a monitor exactly 1080px tall), accepted deliberately rather
    // than trimmed further - that specific combination is a narrow edge
    // case, and even then the overflow is small, not a severe breakage.
    // A shorter window that scrolled internally would have had more
    // slack to work with, but per explicit user preference this shows
    // everything statically instead; splitting a category further (like
    // Bar/Modules already were) is the intended fix if a future addition
    // ever makes one category's content taller than this.
    implicitHeight: 1040

    anchor.item: SettingsState.targetItem
    // Horizontally centered under the bar, same as CalendarFlyout centers
    // under the clock - anchor.item is now the bar's full-width surface,
    // not a small edge icon, so centering here means centered on screen.
    anchor.rect.x: SettingsState.targetItem ? (SettingsState.targetItem.width - implicitWidth) / 2 : 0
    // Opens above the bar instead of below it when BarConfig.position is
    // "bottom" - see BarConfig.popupAnchorY's own comment.
    anchor.rect.y: BarConfig.popupAnchorY(SettingsState.targetItem, implicitHeight)

    property string activeCategory: "bar"

    // Lets an external caller (AudioMixerPanel.qml's gear button) open
    // Settings directly to a specific tab instead of whatever
    // activeCategory was last left on - see SettingsState.requestedCategory
    // itself for why. Only acts when a real request is pending, so a plain
    // open (Control Center's gear button, which never touches
    // requestedCategory) keeps today's "reopens to the last tab you were
    // on" behavior unchanged.
    onVisibleChanged: {
        if (settingsWindow.visible && SettingsState.requestedCategory !== "") {
            settingsWindow.activeCategory = SettingsState.requestedCategory
            SettingsState.requestedCategory = ""
        }
    }

    // ==================== Module chip drag-and-drop ====================
    // Backs the Bar Modules/Control Center tabs' drag-to-reorder chips
    // (ModuleChip.qml). Deliberately NOT per-chip Drag/DropArea +
    // reparenting (the more "native" QML pattern) - a dragged chip is
    // itself one of a Repeater's generated delegates, and reparenting a
    // Repeater-owned item away mid-drag risks fighting the Repeater's own
    // child bookkeeping, confirmed a real concern rather than a
    // theoretical one by checking how Qt's own Repeater documentation
    // describes item ownership. Instead: the real chip stays exactly
    // where it is (dimmed) for the whole drag, a single shared ghost
    // Rectangle (dragGhost below) follows the cursor, and only on release
    // does anything about the actual module order change - at which point
    // the Repeater naturally regenerates every chip in its new
    // position/section anyway, so nothing ever needs un-reparenting.
    property bool chipDragActive: false
    property string chipDragId: ""
    property string chipDragLabel: ""
    // "left"/"center"/"right" for the Bar Modules tab, "tray" for Control
    // Center - which reorder function endChipDrag() should call.
    property string chipDragOrigin: ""
    property real chipDragX: 0
    property real chipDragY: 0
    property real chipDragOffsetX: 0
    property real chipDragOffsetY: 0

    function startChipDrag(id, label, origin, windowX, windowY, chipW, chipH) {
        settingsWindow.chipDragActive = true
        settingsWindow.chipDragId = id
        settingsWindow.chipDragLabel = label
        settingsWindow.chipDragOrigin = origin
        settingsWindow.chipDragOffsetX = chipW / 2
        settingsWindow.chipDragOffsetY = chipH / 2
        settingsWindow.chipDragX = windowX
        settingsWindow.chipDragY = windowY
    }

    function updateChipDrag(windowX, windowY) {
        settingsWindow.chipDragX = windowX
        settingsWindow.chipDragY = windowY
    }

    // Point-in-rect against a drop zone Item's own mapped bounds - shared
    // by both tabs' drop zones.
    function pointInZone(zoneItem, windowX, windowY) {
        if (!zoneItem)
            return false
        const local = zoneItem.mapFromItem(null, windowX, windowY)
        return local.x >= 0 && local.x <= zoneItem.width && local.y >= 0 && local.y <= zoneItem.height
    }

    // Insertion index within a drop zone's chip Flow, excluding the
    // dragged chip itself from consideration - "insert before the first
    // remaining chip whose row is below the drop point, or whose row
    // contains it and whose center sits to the drop point's right";
    // falls off the end (appends) if nothing matches. A reasonable
    // approximation for the handful-of-chips-per-section case this is
    // built for, not attempting pixel-perfect multi-row wrap precision.
    function computeInsertIndex(flowItem, draggedId, windowX, windowY) {
        const local = flowItem.mapFromItem(null, windowX, windowY)
        const candidates = []
        for (let i = 0; i < flowItem.children.length; i++) {
            const child = flowItem.children[i]
            if (child.moduleId !== undefined && child.moduleId !== draggedId)
                candidates.push(child)
        }
        for (let i = 0; i < candidates.length; i++) {
            const child = candidates[i]
            const cx = child.x + child.width / 2
            const inRow = local.y >= child.y && local.y <= child.y + child.height
            if (local.y < child.y || (inRow && local.x < cx))
                return i
        }
        return candidates.length
    }

    // Called on release - hit-tests the drop point against whichever
    // tab's drop zones are actually visible right now (bar_left/
    // bar_center/bar_right/tray - the zone ids referenced here are
    // declared further down this same file, inside each tab's own
    // content Column; a plain JS function like this one only resolves
    // them at call time, once the whole window is already built, so the
    // "used before declared" ordering here is fine) and commits the
    // reorder through ModulesConfig.
    function endChipDrag(windowX, windowY) {
        const id = settingsWindow.chipDragId
        const origin = settingsWindow.chipDragOrigin
        settingsWindow.chipDragActive = false
        if (id === "")
            return

        if (origin === "tray") {
            if (!settingsWindow.pointInZone(trayZone, windowX, windowY))
                return
            const ids = ModulesConfig.trayModulesForSettings().filter(function (i) { return i !== id })
            const idx = settingsWindow.computeInsertIndex(trayFlow, id, windowX, windowY)
            ids.splice(idx, 0, id)
            ModulesConfig.reorderTrayModules(ids)
            return
        }

        const zones = [
            { section: "left", zone: barLeftZone, flow: barLeftFlow },
            { section: "center", zone: barCenterZone, flow: barCenterFlow },
            { section: "right", zone: barRightZone, flow: barRightFlow }
        ]
        for (let i = 0; i < zones.length; i++) {
            if (!settingsWindow.pointInZone(zones[i].zone, windowX, windowY))
                continue
            const ids = ModulesConfig.barModulesForSettings(zones[i].section).filter(function (mid) { return mid !== id })
            const idx = settingsWindow.computeInsertIndex(zones[i].flow, id, windowX, windowY)
            ids.splice(idx, 0, id)
            ModulesConfig.reorderBarSection(zones[i].section, ids)
            return
        }
        // Dropped outside every zone - no-op, the chip just stays where
        // it was (the Repeater never actually moved it in the first
        // place, since the real reorder only happens here on a
        // successful drop).
    }

    readonly property var categories: [
        { id: "general", label: "General", icon: "" },
        { id: "defaults", label: "Defaults", icon: "" },
        { id: "layout", label: "Layout", icon: "" },
        { id: "colors", label: "Colors", icon: "" },
        { id: "wallpaper", label: "Wallpaper", icon: "" },
        { id: "bar", label: "Bar", icon: "" },
        { id: "dock", label: "Dock", icon: "" },
        { id: "audio", label: "Audio", icon: "" },
        { id: "notifications", label: "Notifications", icon: "" },
        { id: "osd", label: "OSD", icon: "" },
        { id: "nightlight", label: "Night Light", icon: "" },
        { id: "clipboard", label: "Clipboard", icon: "" },
        { id: "battery", label: "Battery", icon: "" },
        { id: "profile", label: "Profile", icon: "" },
        { id: "datetime", label: "Date/Time", icon: "" },
        { id: "barModules", label: "Bar Modules", icon: "" },
        { id: "controlCenterModules", label: "Control Center", icon: "" },
        { id: "weather", label: "Weather", icon: "" }
    ]

    readonly property var moduleNames: ({
        kernel: "Kernel version",
        cpu: "CPU load",
        cpuTemp: "CPU temperature",
        gpuTemp: "GPU temperature",
        network: "Network status",
        wifi: "Wifi",
        volume: "Volume",
        stayAwake: "Stay awake",
        nightLight: "Night light",
        dnd: "Do not disturb",
        bluetooth: "Bluetooth",
        mediaPlayer: "Media player",
        clipboard: "Clipboard history",
        notifications: "Notifications",
        wallpaper: "Wallpaper picker",
        battery: "Battery status"
    })

    // Control Center tab's own chip labels - a few of these read
    // differently in Control Center's actual tile grid than
    // moduleNames' own bar-context wording above (network -> "Ethernet",
    // matching ControlCenter.qml's own tile after the earlier "Network"
    // to "Ethernet" rename; nightLight/dnd/clipboard/stayAwake trimmed to
    // match ControlCenter.qml's own tile labels exactly) - falls back to
    // moduleNames for any id not listed here.
    readonly property var ccModuleNames: ({
        stayAwake: "Stay Awake",
        dnd: "Do Not Disturb",
        nightLight: "Night Light",
        network: "Ethernet",
        wifi: "Wifi",
        clipboard: "Clipboard",
        bluetooth: "Bluetooth"
    })

    function categoryLabel(id) {
        for (var i = 0; i < settingsWindow.categories.length; i++) {
            if (settingsWindow.categories[i].id === id)
                return settingsWindow.categories[i].label
        }
        return ""
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.bg

        // Close button, same icon/style as Control Center's own - matters
        // more here than it did as a centered FloatingWindow, since this
        // now opens anchored under Control Center's gear button rather
        // than in the middle of the screen, without an obvious "click
        // outside to dismiss" affordance.
        NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            z: 1
            baseSize: 26
            icon: ""
            tooltipText: "Close"
            onClicked: SettingsState.visible = false
        }

        Row {
            anchors.fill: parent

            // --- sidebar ---
            Rectangle {
                width: 180
                height: parent.height
                color: Colors.pill

                Column {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 2

                    Repeater {
                        model: settingsWindow.categories

                        Rectangle {
                            id: navItem
                            required property var modelData
                            width: parent.width
                            height: 36
                            radius: 6
                            color: settingsWindow.activeCategory === modelData.id ? Colors.pillActive : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                spacing: 10

                                NIcon {
                                    icon: navItem.modelData.icon
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    pointSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                NText {
                                    text: navItem.modelData.label
                                    color: settingsWindow.activeCategory === navItem.modelData.id ? Colors.text : Colors.textMuted
                                    pointSize: Style.fontSizeM
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: settingsWindow.activeCategory = navItem.modelData.id
                            }
                        }
                    }
                }
            }

            // --- content pane ---
            Item {
                width: parent.width - 180
                height: parent.height

                NScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: 20

                    Column {
                        id: contentColumn
                        width: scrollView.availableWidth
                        spacing: 4

                        NText {
                            text: settingsWindow.categoryLabel(settingsWindow.activeCategory)
                            pointSize: Style.fontSizeXL
                            font.weight: Style.fontWeightBold
                            color: Colors.text
                            bottomPadding: 16
                        }

                        // ==================== General ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "general"

                            NText {
                                text: "About this system"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                bottomPadding: 4
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 12
                                NText { text: "OS"; width: 140; color: Colors.textMuted; pointSize: Style.fontSizeS }
                                NText { text: HostService.osPretty || "Unknown"; color: Colors.text; pointSize: Style.fontSizeM }
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 12
                                NText { text: "Hostname"; width: 140; color: Colors.textMuted; pointSize: Style.fontSizeS }
                                NText { text: HostService.hostName || "Unknown"; color: Colors.text; pointSize: Style.fontSizeM }
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 12
                                NText { text: "Uptime"; width: 140; color: Colors.textMuted; pointSize: Style.fontSizeS }
                                NText { text: HostService.uptimeText || "Unknown"; color: Colors.text; pointSize: Style.fontSizeM }
                            }

                            NText {
                                text: "More general, non-bar-specific settings will land here over time - this is reserved for them rather than left out entirely."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 10
                            }
                        }

                        // ==================== Defaults ====================
                        Column {
                            width: parent.width
                            spacing: 16
                            visible: settingsWindow.activeCategory === "defaults"

                            NComboBox {
                                width: parent.width
                                label: "Icon theme"
                                description: "Applies to this shell's own icons (Dock/Launcher) and GTK apps."
                                model: DefaultsConfig.availableIconThemes
                                currentKey: DefaultsConfig.iconTheme
                                placeholder: "System default"
                                onSelected: key => DefaultsConfig.setIconTheme(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Cursor theme"
                                description: "Applies to GTK/Qt apps and this WM's own pointer cursor - both only pick it up at their own next restart."
                                model: DefaultsConfig.availableCursorThemes
                                currentKey: DefaultsConfig.cursorTheme
                                placeholder: "System default"
                                onSelected: key => DefaultsConfig.setCursorTheme(key)
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Cursor size"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 16
                                    to: 48
                                    value: DefaultsConfig.cursorSize
                                    onMoved: DefaultsConfig.setCursorSize(value)
                                }

                                NText {
                                    text: Math.round(DefaultsConfig.cursorSize) + "px"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            NComboBox {
                                width: parent.width
                                label: "Font family"
                                description: "Applies to this shell's own text and GTK apps."
                                model: DefaultsConfig.availableFonts
                                currentKey: DefaultsConfig.fontFamily
                                placeholder: "System default"
                                onSelected: key => DefaultsConfig.setFontFamily(key)
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Font size"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 8
                                    to: 16
                                    value: DefaultsConfig.fontSize
                                    onMoved: DefaultsConfig.setFontSize(value)
                                }

                                NText {
                                    text: Math.round(DefaultsConfig.fontSize) + "pt"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            NText {
                                text: "Default apps"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                topPadding: 8
                            }

                            NText {
                                text: "Every dropdown below applies immediately (xdg-settings for the browser, xdg-mime for the rest) - no restart needed."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                bottomPadding: 4
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default web browser"
                                model: DefaultsConfig.availableBrowsers
                                currentKey: DefaultsConfig.defaultBrowser
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultBrowser(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default file explorer"
                                model: DefaultsConfig.availableFileExplorers
                                currentKey: DefaultsConfig.defaultFileExplorer
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultFileExplorer(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default text editor"
                                model: DefaultsConfig.availableTextEditors
                                currentKey: DefaultsConfig.defaultTextEditor
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultTextEditor(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default image viewer"
                                model: DefaultsConfig.availableImageViewers
                                currentKey: DefaultsConfig.defaultImageViewer
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultImageViewer(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default email client"
                                model: DefaultsConfig.availableEmailClients
                                currentKey: DefaultsConfig.defaultEmailClient
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultEmailClient(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Default PDF viewer"
                                model: DefaultsConfig.availablePdfViewers
                                currentKey: DefaultsConfig.defaultPdfViewer
                                placeholder: "Not set"
                                onSelected: key => DefaultsConfig.setDefaultPdfViewer(key)
                            }

                            NTextInput {
                                width: parent.width
                                label: "Screenshot folder"
                                description: "Where Control Center's Screenshot tile saves to."
                                text: DefaultsConfig.screenshotFolder
                                placeholderText: Quickshell.env("HOME") + "/Pictures/Screenshots"
                                onEditingFinished: DefaultsConfig.setScreenshotFolder(text)
                                onAccepted: DefaultsConfig.setScreenshotFolder(text)
                            }

                            NText {
                                text: "Icon/cursor/font theme changes need a real restart to take visual effect (Qt/GTK/this WM only read them at startup). \"Reload Shell UI\" only reloads this shell's own QML live - it can't reach any of that. A genuine visual change needs the shell process restarted (kill and relaunch qs, or log out and back in)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 4
                            }

                            NButton {
                                text: "Reload Shell UI"
                                onClicked: DefaultsConfig.restartShell()
                            }
                        }

                        // ==================== Layout ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "layout"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Bar layout"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Status Bar"
                                        pointSize: Style.fontSizeS
                                        checked: BarConfig.layoutMode === "statusbar"
                                        onClicked: BarConfig.setLayoutMode("statusbar")
                                    }

                                    NTabButton {
                                        text: "Taskbar"
                                        pointSize: Style.fontSizeS
                                        checked: BarConfig.layoutMode === "taskbar"
                                        onClicked: BarConfig.setLayoutMode("taskbar")
                                    }
                                }
                            }

                            NText {
                                text: BarConfig.layoutMode === "taskbar"
                                    ? "Taskbar mode: launcher + pinned/running apps embedded directly in the bar (left), workspaces centered, status modules + clock + Control Center on the right - a Plasma/Windows-style layout. The standalone Dock's own window is hidden while this is active; pin apps the same way as before (right-click a result in the launcher)."
                                    : "Status Bar mode: the original layout - logo + workspaces (left), clock (center), status modules + Control Center (right). Enable the separate Dock (see the Dock tab) if you also want a pinned/running-apps strip."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Bar position"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Top"
                                        pointSize: Style.fontSizeS
                                        checked: BarConfig.position === "top"
                                        onClicked: BarConfig.setPosition("top")
                                    }

                                    NTabButton {
                                        text: "Bottom"
                                        pointSize: Style.fontSizeS
                                        checked: BarConfig.position === "bottom"
                                        onClicked: BarConfig.setPosition("bottom")
                                    }
                                }
                            }

                            NText {
                                text: "Applies in either layout above. Left/right bar positions (like the dock already supports) are a possible future addition, not available yet."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                            }
                        }

                        // ==================== Colors ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "colors"

                            NText {
                                text: "Presets"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                bottomPadding: 4
                            }

                            Flow {
                                width: parent.width
                                spacing: 10

                                Repeater {
                                    model: ThemeConfig.presets

                                    Rectangle {
                                        id: presetCard
                                        required property var modelData
                                        width: 110
                                        height: 58
                                        radius: 6
                                        color: Colors.pill
                                        border.width: 1
                                        border.color: presetHover.containsMouse ? Colors.pillActive : "transparent"

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 4

                                                Rectangle { width: 14; height: 14; radius: 7; color: presetCard.modelData.primary }
                                                Rectangle { width: 14; height: 14; radius: 7; color: presetCard.modelData.secondary }
                                                Rectangle { width: 14; height: 14; radius: 7; color: presetCard.modelData.tertiary }
                                                Rectangle { width: 14; height: 14; radius: 7; color: presetCard.modelData.borderAccent }
                                            }

                                            NText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: presetCard.modelData.name
                                                color: Colors.text
                                                pointSize: Style.fontSizeXS
                                            }
                                        }

                                        MouseArea {
                                            id: presetHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: ThemeConfig.applyPreset(presetCard.modelData.id)
                                        }
                                    }
                                }
                            }

                            NText {
                                text: "Applying a preset overwrites all five colors and the window border accent below - hand-edit any of them afterward if you just want to tweak one."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 16
                            }

                            NText {
                                text: "Custom colors"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                bottomPadding: 4
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Primary"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.primary; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.primary
                                    placeholderText: "#5b7fd6"
                                    onEditingFinished: ThemeConfig.setPrimary(text)
                                    onAccepted: ThemeConfig.setPrimary(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Secondary"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.secondary; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.secondary
                                    placeholderText: "#4da4a6"
                                    onEditingFinished: ThemeConfig.setSecondary(text)
                                    onAccepted: ThemeConfig.setSecondary(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Tertiary"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.tertiary; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.tertiary
                                    placeholderText: "#c55a63"
                                    onEditingFinished: ThemeConfig.setTertiary(text)
                                    onAccepted: ThemeConfig.setTertiary(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Text"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.text; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.text
                                    placeholderText: "#e8e6f0"
                                    onEditingFinished: ThemeConfig.setText(text)
                                    onAccepted: ThemeConfig.setText(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Background"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.background; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.background
                                    placeholderText: "#0c0b1a"
                                    onEditingFinished: ThemeConfig.setBackground(text)
                                    onAccepted: ThemeConfig.setBackground(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Bar color"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Colors.barBg; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.barBackground
                                    placeholderText: "Follows Background"
                                    onEditingFinished: ThemeConfig.setBarBackground(text)
                                    onAccepted: ThemeConfig.setBarBackground(text)
                                }
                            }

                            NText {
                                text: "Leave the bar color field blank to have the bar follow the Background color above - set it to override just the bar with its own color instead."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 16
                            }

                            NText {
                                text: "\"Text muted\", pill/hover backgrounds, and the error/danger red stay fixed for now - only these five colors and the border accent below are themeable."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 16
                            }

                            NText {
                                text: "Window border accent"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                bottomPadding: 4
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText { text: "Focused window border"; width: 170; anchors.verticalCenter: parent.verticalCenter; color: Colors.text; pointSize: Style.fontSizeM }
                                Rectangle { width: 24; height: 24; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: ThemeConfig.borderAccent; border.width: 1; border.color: Colors.textMuted }
                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ThemeConfig.borderAccent
                                    placeholderText: "#3bb2d4"
                                    onEditingFinished: ThemeConfig.setBorderAccent(text)
                                    onAccepted: ThemeConfig.setBorderAccent(text)
                                }
                            }

                            NText {
                                text: "This is a window-manager-level setting (zaris.conf's col.active_border), not a Quickshell one - it takes effect live, but an already-focused window's border only repaints on its next focus change."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                            }
                        }

                        // ==================== Wallpaper ====================
                        // Every field here just exposes WallpaperService.qml's
                        // existing properties/setters - that singleton already
                        // had a real folder/rotation backend (built for
                        // WallpaperPickerPanel.qml's own grid picker), this
                        // tab didn't need any new backend work, just a
                        // Settings-side surface for it.
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "wallpaper"

                            NText {
                                text: "Wallpaper folder"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                            }

                            Row {
                                id: wallpaperFolderRow
                                width: parent.width
                                height: 40
                                spacing: 12

                                NTextInput {
                                    width: wallpaperFolderRow.width - 24 - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: WallpaperService.directory
                                    onEditingFinished: WallpaperService.setDirectory(text)
                                    onAccepted: WallpaperService.setDirectory(text)
                                }

                                NIconButton {
                                    baseSize: 28
                                    icon: ""
                                    enabled: DefaultsConfig.defaultFileExplorer !== ""
                                    tooltipText: DefaultsConfig.defaultFileExplorer !== "" ? "Browse..." : "Set a Default File Explorer first (Defaults tab)"
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        const entry = DesktopEntries.byId(DefaultsConfig.defaultFileExplorer)
                                        if (entry)
                                            entry.execute()
                                    }
                                }
                            }

                            NText {
                                text: "Scanned non-recursively for images (jpg/jpeg/png/webp/bmp) - Browse opens your Default File Explorer to look around, it doesn't pick a folder directly. " + WallpaperService.images.length + " image(s) found."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Rotate automatically"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: WallpaperService.rotationEnabled
                                    onToggled: newChecked => WallpaperService.setRotationEnabled(newChecked)
                                }
                            }

                            NComboBox {
                                width: parent.width
                                label: "Rotation interval"
                                enabled: WallpaperService.rotationEnabled
                                model: [
                                    { key: "5", name: "Every 5 minutes" },
                                    { key: "15", name: "Every 15 minutes" },
                                    { key: "30", name: "Every 30 minutes" },
                                    { key: "60", name: "Every hour" },
                                    { key: "180", name: "Every 3 hours" }
                                ]
                                currentKey: "" + WallpaperService.rotationIntervalMinutes
                                onSelected: key => WallpaperService.setRotationInterval(parseInt(key, 10))
                            }

                            NButton {
                                text: "Open Wallpaper Picker"
                                fontSize: Style.fontSizeS
                                backgroundColor: Colors.pill
                                textColor: Colors.text
                                onClicked: WallpaperPickerPanelState.visible = true
                            }
                        }

                        // ==================== Profile ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "profile"

                            NTextInput {
                                width: 260
                                label: "Display name"
                                description: "Shown in the Control Center - separate from your actual account username, which stays " + HostService.username + "."
                                placeholderText: HostService.username
                                text: HostService.identityFile.adapter.customDisplayName
                                onEditingFinished: HostService.setCustomDisplayName(text)
                                onAccepted: HostService.setCustomDisplayName(text)
                            }

                            NText {
                                text: "Profile picture"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                            }

                            Row {
                                id: avatarPathRow
                                width: parent.width
                                height: 40
                                spacing: 12

                                NTextInput {
                                    width: avatarPathRow.width - 24 - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    placeholderText: "/path/to/image.png"
                                    onEditingFinished: AvatarPickerPanelState.setAvatar(text)
                                    onAccepted: AvatarPickerPanelState.setAvatar(text)
                                }

                                NIconButton {
                                    baseSize: 28
                                    icon: ""
                                    enabled: DefaultsConfig.defaultFileExplorer !== ""
                                    tooltipText: DefaultsConfig.defaultFileExplorer !== "" ? "Browse..." : "Set a Default File Explorer first (Defaults tab)"
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        const entry = DesktopEntries.byId(DefaultsConfig.defaultFileExplorer)
                                        if (entry)
                                            entry.execute()
                                    }
                                }
                            }

                            NText {
                                text: "Copied to ~/.face on Enter/blur - opens your Default File Explorer to browse for one, doesn't pick a file directly. No \"currently set\" path to show, only whichever image was copied there last."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 4
                            }

                        }

                        // ==================== Date/Time ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "datetime"

                            NComboBox {
                                width: parent.width
                                label: "First day of the week"
                                model: DateTimeConfig.firstDayOfWeekOptions
                                currentKey: DateTimeConfig.firstDayOfWeek
                                onSelected: key => DateTimeConfig.setFirstDayOfWeek(key)
                            }

                            NText {
                                text: "Controls the calendar's month grid, both in Control Center and the bar's calendar flyout."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                bottomPadding: 4
                            }

                            NComboBox {
                                width: parent.width
                                label: "Date format"
                                model: DateTimeConfig.dateFormatOptions
                                currentKey: DateTimeConfig.dateFormat
                                onSelected: key => DateTimeConfig.setDateFormat(key)
                            }

                            NComboBox {
                                width: parent.width
                                label: "Time format"
                                model: DateTimeConfig.timeFormatOptions
                                currentKey: DateTimeConfig.timeFormat
                                onSelected: key => DateTimeConfig.setTimeFormat(key)
                            }

                            NText {
                                text: "Applies to the bar's clock. Previews above show today's actual date/time."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 4
                            }
                        }

                        // ==================== Weather ====================
                        // Split out from Profile - the location field/toggle
                        // had no real connection to identity settings beyond
                        // both being "things about how you show up", and
                        // Weather has enough of its own surface (more is
                        // planned - see the backlog) to earn its own tab
                        // rather than staying bolted onto Profile.
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "weather"

                            NTextInput {
                                width: 260
                                label: "Weather location"
                                description: WeatherService.manualLocationQuery === ""
                                    ? "Auto-detected via your IP" + (WeatherService.haveData ? " as " + WeatherService.locationName : "") + ". Type a city to override, or leave blank."
                                    : "Currently set to \"" + WeatherService.manualLocationQuery + "\". Clear this field to go back to auto-detection."
                                placeholderText: "Auto (IP-based)"
                                text: WeatherService.manualLocationQuery
                                onEditingFinished: {
                                    if (text.trim() === "")
                                        WeatherService.useAutoLocation()
                                    else
                                        WeatherService.setManualLocation(text.trim())
                                }
                                onAccepted: {
                                    if (text.trim() === "")
                                        WeatherService.useAutoLocation()
                                    else
                                        WeatherService.setManualLocation(text.trim())
                                }
                            }

                            Row {
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Hide location"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: WeatherService.hideLocation
                                    onToggled: newChecked => WeatherService.setHideLocation(newChecked)
                                }
                            }

                            NText {
                                text: "Keeps the city name out of the weather widget (Control Center, calendar) - the temperature/condition/hi-lo still shows."
                                width: 320
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 4
                            }
                        }

                        // ==================== Bar ====================
                        // Per-module Enabled/Screens/In-tray table moved out
                        // to its own "Modules" tab below - keeping it here
                        // alongside opacity/height made this one tab by far
                        // the tallest in the whole window, which mattered
                        // once every tab needed to fit without scrolling
                        // (see the window's own implicitHeight comment).
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "bar"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Background opacity"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0
                                    to: 1
                                    value: BarConfig.backgroundOpacity
                                    onMoved: BarConfig.setBackgroundOpacity(value)
                                }

                                NText {
                                    text: Math.round(BarConfig.backgroundOpacity * 100) + "%"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Height"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 32
                                    to: 96
                                    value: BarConfig.height
                                    onMoved: BarConfig.setHeight(value)
                                }

                                NText {
                                    text: BarConfig.height + "px"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            NText {
                                text: "Icons"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                topPadding: 12
                                bottomPadding: 4
                            }

                            Row {
                                id: launcherIconRow
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText {
                                    text: "Launcher icon"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                Image {
                                    width: 24
                                    height: 24
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "file://" + BarConfig.launcherIcon
                                }

                                NTextInput {
                                    width: launcherIconRow.width - 170 - 24 - 24 - 12 - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: BarConfig.launcherIcon
                                    onEditingFinished: BarConfig.setLauncherIcon(text)
                                    onAccepted: BarConfig.setLauncherIcon(text)
                                }

                                NIconButton {
                                    baseSize: 28
                                    icon: ""
                                    tooltipText: "Browse..."
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: IconPickerPanelState.open("launcher")
                                }
                            }

                            Row {
                                id: ccIconRow
                                width: parent.width
                                height: 40
                                spacing: 12

                                NText {
                                    text: "Control Center icon"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                Image {
                                    width: 24
                                    height: 24
                                    fillMode: Image.PreserveAspectCrop
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "file://" + BarConfig.controlCenterIcon
                                }

                                NTextInput {
                                    width: ccIconRow.width - 170 - 24 - 24 - 12 - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: BarConfig.controlCenterIcon
                                    onEditingFinished: BarConfig.setControlCenterIcon(text)
                                    onAccepted: BarConfig.setControlCenterIcon(text)
                                }

                                NIconButton {
                                    baseSize: 28
                                    icon: ""
                                    tooltipText: "Browse..."
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: IconPickerPanelState.open("controlCenter")
                                }
                            }

                            NText {
                                text: "Absolute file paths to any image - not limited to the bundled assets in ~/.config/quickshell/assets/."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                            }
                        }

                        // ==================== Bar Modules ====================
                        // Drag-and-drop chip UI, replacing the old flat
                        // enable/screens/tray table for the bar-shown half
                        // of ModulesConfig - see Settings' own
                        // chipDrag*/ModuleChip.qml/ModulesConfig.qml
                        // comments for the full mechanism. Per-monitor
                        // "screens" scoping (previously an All/Primary
                        // quick toggle here) is hand-edit-only now - a
                        // deliberate scope trade for the new reorder
                        // capability, see ROADMAP.md's own writeup.
                        Column {
                            width: parent.width
                            spacing: 16
                            visible: settingsWindow.activeCategory === "barModules"

                            NText {
                                text: "Drag a chip to reorder it or move it between sections. Click \u00d7 to remove a module from the bar."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                NText { text: "Left"; color: Colors.text; pointSize: Style.fontSizeM; font.weight: Style.fontWeightBold }

                                Rectangle {
                                    id: barLeftZone
                                    width: parent.width
                                    height: Math.max(50, barLeftFlow.implicitHeight + 16)
                                    radius: Style.radiusS
                                    color: Colors.pill
                                    border.width: 2
                                    border.color: settingsWindow.chipDragActive && settingsWindow.pointInZone(barLeftZone, settingsWindow.chipDragX, settingsWindow.chipDragY) ? Colors.mPrimary : "transparent"

                                    Flow {
                                        id: barLeftFlow
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Repeater {
                                            model: ModulesConfig.barModulesForSettings("left")

                                            ModuleChip {
                                                required property string modelData
                                                moduleId: modelData
                                                label: settingsWindow.moduleNames[modelData] || modelData
                                                dimmed: settingsWindow.chipDragActive && settingsWindow.chipDragId === modelData
                                                onChipPressed: (wx, wy) => settingsWindow.startChipDrag(modelData, label, "left", wx, wy, width, height)
                                                onChipPositionChanged: (wx, wy) => settingsWindow.updateChipDrag(wx, wy)
                                                onChipReleased: (wx, wy) => settingsWindow.endChipDrag(wx, wy)
                                                onRemoveClicked: ModulesConfig.removeFromBar(modelData)
                                            }
                                        }
                                    }
                                }

                                NComboBox {
                                    width: 260
                                    placeholder: "Add a module..."
                                    currentKey: ""
                                    model: ModulesConfig.barModulesAvailableToAdd().map(function (id) { return { key: id, name: settingsWindow.moduleNames[id] || id } })
                                    onSelected: key => ModulesConfig.addToBarSection(key, "left")
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                NText { text: "Center"; color: Colors.text; pointSize: Style.fontSizeM; font.weight: Style.fontWeightBold }

                                Rectangle {
                                    id: barCenterZone
                                    width: parent.width
                                    height: Math.max(50, barCenterFlow.implicitHeight + 16)
                                    radius: Style.radiusS
                                    color: Colors.pill
                                    border.width: 2
                                    border.color: settingsWindow.chipDragActive && settingsWindow.pointInZone(barCenterZone, settingsWindow.chipDragX, settingsWindow.chipDragY) ? Colors.mPrimary : "transparent"

                                    Flow {
                                        id: barCenterFlow
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Repeater {
                                            model: ModulesConfig.barModulesForSettings("center")

                                            ModuleChip {
                                                required property string modelData
                                                moduleId: modelData
                                                label: settingsWindow.moduleNames[modelData] || modelData
                                                dimmed: settingsWindow.chipDragActive && settingsWindow.chipDragId === modelData
                                                onChipPressed: (wx, wy) => settingsWindow.startChipDrag(modelData, label, "center", wx, wy, width, height)
                                                onChipPositionChanged: (wx, wy) => settingsWindow.updateChipDrag(wx, wy)
                                                onChipReleased: (wx, wy) => settingsWindow.endChipDrag(wx, wy)
                                                onRemoveClicked: ModulesConfig.removeFromBar(modelData)
                                            }
                                        }
                                    }
                                }

                                NComboBox {
                                    width: 260
                                    placeholder: "Add a module..."
                                    currentKey: ""
                                    model: ModulesConfig.barModulesAvailableToAdd().map(function (id) { return { key: id, name: settingsWindow.moduleNames[id] || id } })
                                    onSelected: key => ModulesConfig.addToBarSection(key, "center")
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 6

                                NText { text: "Right"; color: Colors.text; pointSize: Style.fontSizeM; font.weight: Style.fontWeightBold }

                                Rectangle {
                                    id: barRightZone
                                    width: parent.width
                                    height: Math.max(50, barRightFlow.implicitHeight + 16)
                                    radius: Style.radiusS
                                    color: Colors.pill
                                    border.width: 2
                                    border.color: settingsWindow.chipDragActive && settingsWindow.pointInZone(barRightZone, settingsWindow.chipDragX, settingsWindow.chipDragY) ? Colors.mPrimary : "transparent"

                                    Flow {
                                        id: barRightFlow
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Repeater {
                                            model: ModulesConfig.barModulesForSettings("right")

                                            ModuleChip {
                                                required property string modelData
                                                moduleId: modelData
                                                label: settingsWindow.moduleNames[modelData] || modelData
                                                dimmed: settingsWindow.chipDragActive && settingsWindow.chipDragId === modelData
                                                onChipPressed: (wx, wy) => settingsWindow.startChipDrag(modelData, label, "right", wx, wy, width, height)
                                                onChipPositionChanged: (wx, wy) => settingsWindow.updateChipDrag(wx, wy)
                                                onChipReleased: (wx, wy) => settingsWindow.endChipDrag(wx, wy)
                                                onRemoveClicked: ModulesConfig.removeFromBar(modelData)
                                            }
                                        }
                                    }
                                }

                                NComboBox {
                                    width: 260
                                    placeholder: "Add a module..."
                                    currentKey: ""
                                    model: ModulesConfig.barModulesAvailableToAdd().map(function (id) { return { key: id, name: settingsWindow.moduleNames[id] || id } })
                                    onSelected: key => ModulesConfig.addToBarSection(key, "right")
                                }
                            }

                            NText {
                                text: "Per-monitor placement (\"screens\": [\"DisplayPort-1\"], matching `xrandr` output names) is hand-edit-only in modules.json - not covered by this tab."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }
                        }

                        // ==================== Control Center (modules) ====================
                        Column {
                            width: parent.width
                            spacing: 16
                            visible: settingsWindow.activeCategory === "controlCenterModules"

                            NText {
                                text: "Reorders Control Center's Ethernet/Wifi/Clipboard/Bluetooth/Stay Awake/Night Light row. Its other sections (weather, media, audio, Wallpaper/Screenshot, Balanced/Battery) aren't reorderable yet."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Rectangle {
                                id: trayZone
                                width: parent.width
                                height: Math.max(50, trayFlow.implicitHeight + 16)
                                radius: Style.radiusS
                                color: Colors.pill
                                border.width: 2
                                border.color: settingsWindow.chipDragActive && settingsWindow.pointInZone(trayZone, settingsWindow.chipDragX, settingsWindow.chipDragY) ? Colors.mPrimary : "transparent"

                                Flow {
                                    id: trayFlow
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Repeater {
                                        model: ModulesConfig.trayModulesForSettings()

                                        ModuleChip {
                                            required property string modelData
                                            moduleId: modelData
                                            label: settingsWindow.ccModuleNames[modelData] || settingsWindow.moduleNames[modelData] || modelData
                                            dimmed: settingsWindow.chipDragActive && settingsWindow.chipDragId === modelData
                                            onChipPressed: (wx, wy) => settingsWindow.startChipDrag(modelData, label, "tray", wx, wy, width, height)
                                            onChipPositionChanged: (wx, wy) => settingsWindow.updateChipDrag(wx, wy)
                                            onChipReleased: (wx, wy) => settingsWindow.endChipDrag(wx, wy)
                                            onRemoveClicked: ModulesConfig.removeFromTray(modelData)
                                        }
                                    }
                                }
                            }

                            NComboBox {
                                width: 260
                                placeholder: "Add a module..."
                                currentKey: ""
                                model: ModulesConfig.trayModulesAvailableToAdd().map(function (id) { return { key: id, name: settingsWindow.ccModuleNames[id] || settingsWindow.moduleNames[id] || id } })
                                onSelected: key => ModulesConfig.addToTray(key)
                            }

                            NText {
                                text: "System gauges"
                                color: Colors.text
                                pointSize: Style.fontSizeM
                                font.weight: Style.fontWeightBold
                                topPadding: 8
                            }

                            NText {
                                text: "The vertical CPU load/CPU temperature/GPU temperature/RAM stack, shown by default - turn any of these off individually."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "CPU load"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: ModulesConfig.configFile.adapter.ccGaugeCpu
                                    onToggled: newChecked => ModulesConfig.setCcGaugeCpu(newChecked)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "CPU temperature"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: ModulesConfig.configFile.adapter.ccGaugeCpuTemp
                                    onToggled: newChecked => ModulesConfig.setCcGaugeCpuTemp(newChecked)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "GPU temperature"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: ModulesConfig.configFile.adapter.ccGaugeGpuTemp
                                    onToggled: newChecked => ModulesConfig.setCcGaugeGpuTemp(newChecked)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "RAM usage"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: ModulesConfig.configFile.adapter.ccGaugeRam
                                    onToggled: newChecked => ModulesConfig.setCcGaugeRam(newChecked)
                                }
                            }
                        }

                        // ==================== Dock ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "dock"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Enabled"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: DockConfig.enabled
                                    onToggled: newChecked => DockConfig.setEnabled(newChecked)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Mode"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Reserved"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.mode === "reserved"
                                        onClicked: DockConfig.setMode("reserved")
                                    }

                                    NTabButton {
                                        text: "Floating"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.mode === "floating"
                                        onClicked: DockConfig.setMode("floating")
                                    }
                                }
                            }

                            NText {
                                text: "Reserved permanently reserves screen space, like the bar does. Floating overlays on top of windows instead without reserving space - windows can tile underneath it. Pin apps to the dock via right-click on a result in the launcher."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Position"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Top"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "top"
                                        onClicked: DockConfig.setPosition("top")
                                    }

                                    NTabButton {
                                        text: "Bottom"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "bottom"
                                        onClicked: DockConfig.setPosition("bottom")
                                    }

                                    NTabButton {
                                        text: "Left"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "left"
                                        onClicked: DockConfig.setPosition("left")
                                    }

                                    NTabButton {
                                        text: "Right"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.position === "right"
                                        onClicked: DockConfig.setPosition("right")
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Launcher position"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "Start"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.launcherPosition === "start"
                                        onClicked: DockConfig.setLauncherPosition("start")
                                    }

                                    NTabButton {
                                        text: "End"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.launcherPosition === "end"
                                        onClicked: DockConfig.setLauncherPosition("end")
                                    }
                                }
                            }

                            NText {
                                text: "\"Start\" is the top/left-most end of the dock's own strip regardless of position, so it stays meaningful for a vertical (left/right) dock too."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Screens"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NTabBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    tabHeight: 22

                                    NTabButton {
                                        text: "All"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.configFile.adapter.screens === "all"
                                        onClicked: DockConfig.setScreens("all")
                                    }

                                    NTabButton {
                                        text: "Primary"
                                        pointSize: Style.fontSizeS
                                        checked: DockConfig.configFile.adapter.screens === "primary" || DockConfig.configFile.adapter.screens === undefined
                                        onClicked: DockConfig.setScreens("primary")
                                    }
                                }
                            }

                            NText {
                                text: "Pinning to specific monitors by name is JSON-only for now (dock.json's \"screens\" field, an array of exact xrandr output names)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                                bottomPadding: 10
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Background opacity"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 0
                                    to: 1
                                    value: DockConfig.backgroundOpacity
                                    onMoved: DockConfig.setBackgroundOpacity(value)
                                }

                                NText {
                                    text: Math.round(DockConfig.backgroundOpacity * 100) + "%"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: 12
                                visible: DockConfig.enabled

                                NText {
                                    text: "Background color"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: DockConfig.backgroundColor
                                    border.width: 1
                                    border.color: Colors.textMuted
                                }

                                NTextInput {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: DockConfig.backgroundColor
                                    placeholderText: "#0c0b1a"
                                    onEditingFinished: DockConfig.setBackgroundColor(text)
                                    onAccepted: DockConfig.setBackgroundColor(text)
                                }
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                visible: DockConfig.enabled && DockConfig.mode === "floating"

                                NText {
                                    text: "Auto-hide"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: DockConfig.autoHide
                                    onToggled: newChecked => DockConfig.setAutoHide(newChecked)
                                }
                            }

                            NText {
                                text: "Only applies in Floating mode. When on, the dock stays hidden until you hover a small marker at its position, then hides again shortly after you move away."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                visible: DockConfig.enabled && DockConfig.mode === "floating"
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 6
                            }
                        }

                        // ==================== Audio ====================
                        // Reuses the exact same AudioMixer.qml content the
                        // bar's volume-icon popup shows (AudioMixerPanel.qml)
                        // - see that component's own header comment for the
                        // Volumes/Devices sub-tabs and the empirically-
                        // verified Pipewire node filtering behind them.
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "audio"

                            AudioMixer {
                                width: parent.width
                            }
                        }

                        // ==================== Notifications ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "notifications"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Do Not Disturb"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: DndState.paused
                                    onToggled: DndState.toggle()
                                }
                            }

                            NButton {
                                text: "Clear All Notifications"
                                fontSize: Style.fontSizeS
                                backgroundColor: Colors.pill
                                textColor: Colors.text
                                onClicked: NotificationHistoryService.clearAll()
                            }

                            NText {
                                text: "Per-app/per-type notification filtering isn't built yet - every notification (except OSD-type volume/brightness popups, which never go through the notification daemon at all) currently surfaces the same way."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }
                        }

                        // ==================== OSD ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "osd"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Show on-screen popup"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: OSDState.enabled
                                    onToggled: newChecked => OSDState.setEnabled(newChecked)
                                }
                            }

                            NText {
                                text: "Volume/brightness key presses still work either way - this only controls whether a popup shows on screen."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12
                                enabled: OSDState.enabled

                                NText {
                                    text: "Auto-hide after"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 500
                                    to: 5000
                                    stepSize: 100
                                    value: OSDState.hideDelayMs
                                    onMoved: OSDState.setHideDelayMs(Math.round(value))
                                }

                                NText {
                                    text: (OSDState.hideDelayMs / 1000).toFixed(1) + "s"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }
                        }

                        // ==================== Night Light ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "nightlight"

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Automatic schedule"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                ToggleSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: NightLightService.scheduleEnabled
                                    onToggled: newChecked => NightLightService.setScheduleEnabled(newChecked)
                                }
                            }

                            NText {
                                text: "When enabled, this switches on/off automatically at the times below instead of needing the bar/Control Center toggle. The manual toggle still works either way and uses this same color temperature."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            NTextInput {
                                width: 160
                                label: "Sunset (starts)"
                                text: NightLightService.sunset
                                placeholderText: "18:00"
                                onEditingFinished: NightLightService.setSunset(text)
                                onAccepted: NightLightService.setSunset(text)
                            }

                            NTextInput {
                                width: 160
                                label: "Sunrise (ends)"
                                text: NightLightService.sunrise
                                placeholderText: "06:00"
                                onEditingFinished: NightLightService.setSunrise(text)
                                onAccepted: NightLightService.setSunrise(text)
                            }

                            NText {
                                text: "24-hour HH:MM format."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 12

                                NText {
                                    text: "Color temperature"
                                    width: 170
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                }

                                NSlider {
                                    width: 160
                                    anchors.verticalCenter: parent.verticalCenter
                                    from: 2500
                                    to: 6500
                                    stepSize: 100
                                    value: NightLightService.nightTemp
                                    onMoved: NightLightService.setNightTemp(Math.round(value))
                                }

                                NText {
                                    text: NightLightService.nightTemp + "K"
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeS
                                }
                            }

                            NText {
                                text: "Applied via redshift - lower is warmer/more orange."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }
                        }

                        // ==================== Clipboard ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "clipboard"

                            NComboBox {
                                width: parent.width
                                label: "Max history entries"
                                model: [
                                    { key: "20", name: "20 entries" },
                                    { key: "50", name: "50 entries" },
                                    { key: "100", name: "100 entries" },
                                    { key: "200", name: "200 entries" }
                                ]
                                currentKey: "" + ClipboardHistoryService.maxEntries
                                onSelected: key => ClipboardHistoryService.setMaxEntries(parseInt(key, 10))
                            }

                            NText {
                                text: "Oldest entries are dropped once this limit is reached. Currently " + ClipboardHistoryService.items.length + " entr" + (ClipboardHistoryService.items.length === 1 ? "y" : "ies") + " stored."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                            }

                            NButton {
                                text: "Clear History"
                                fontSize: Style.fontSizeS
                                backgroundColor: Colors.pill
                                textColor: Colors.text
                                onClicked: ClipboardHistoryService.wipeAll()
                            }

                            NText {
                                visible: ClipboardHistoryService.dependencyChecked && !ClipboardHistoryService.clipnotifyAvailable
                                text: "clipnotify isn't installed - clipboard history capture is currently inactive. See DEPENDENCIES.md."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.red
                                pointSize: Style.fontSizeXS
                            }
                        }

                        // ==================== Battery ====================
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: settingsWindow.activeCategory === "battery"

                            NText {
                                visible: !BatteryService.batteryPresent
                                text: "No battery detected on this system."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeS
                            }

                            Column {
                                width: parent.width
                                spacing: 12
                                visible: BatteryService.batteryPresent

                                NText {
                                    text: Math.round(BatteryService.batteryPercentage) + "% " + (BatteryService.batteryCharging ? "(charging)" : BatteryService.batteryPluggedIn ? "(plugged in)" : "(on battery)")
                                    color: Colors.text
                                    pointSize: Style.fontSizeM
                                    font.weight: Style.fontWeightBold
                                }

                                Row {
                                    width: parent.width
                                    height: 32
                                    spacing: 12

                                    NText {
                                        text: "Warning threshold"
                                        width: 170
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Colors.text
                                        pointSize: Style.fontSizeM
                                    }

                                    NSlider {
                                        width: 160
                                        anchors.verticalCenter: parent.verticalCenter
                                        from: 5
                                        to: 50
                                        stepSize: 1
                                        value: BatteryService.warningThreshold
                                        onMoved: BatteryService.setWarningThreshold(Math.round(value))
                                    }

                                    NText {
                                        text: Math.round(BatteryService.warningThreshold) + "%"
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Colors.textMuted
                                        pointSize: Style.fontSizeS
                                    }
                                }

                                Row {
                                    width: parent.width
                                    height: 32
                                    spacing: 12

                                    NText {
                                        text: "Critical threshold"
                                        width: 170
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Colors.text
                                        pointSize: Style.fontSizeM
                                    }

                                    NSlider {
                                        width: 160
                                        anchors.verticalCenter: parent.verticalCenter
                                        from: 1
                                        to: 30
                                        stepSize: 1
                                        value: BatteryService.criticalThreshold
                                        onMoved: BatteryService.setCriticalThreshold(Math.round(value))
                                    }

                                    NText {
                                        text: Math.round(BatteryService.criticalThreshold) + "%"
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Colors.textMuted
                                        pointSize: Style.fontSizeS
                                    }
                                }

                                NText {
                                    text: "A notification fires once when battery level crosses below each threshold while unplugged (critical below warning, so keep it the lower number)."
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    color: Colors.textMuted
                                    pointSize: Style.fontSizeXS
                                }
                            }
                        }
                    }
                }
            }
        }

        // Drag ghost + capture surface for the Bar Modules/Control Center
        // tabs' chip drag-and-drop - see settingsWindow's own
        // chipDrag*/startChipDrag/endChipDrag comment for the full
        // mechanism. Sits above everything else (last child = top z-order)
        // but is itself click-through (`enabled`/only visible) while no
        // drag is active, so it never interferes with normal clicks
        // anywhere else in Settings.
        MouseArea {
            anchors.fill: parent
            visible: settingsWindow.chipDragActive
            enabled: settingsWindow.chipDragActive
            hoverEnabled: true
            onPositionChanged: mouse => {
                const p = mapToItem(null, mouse.x, mouse.y)
                settingsWindow.updateChipDrag(p.x, p.y)
            }
            onReleased: mouse => {
                const p = mapToItem(null, mouse.x, mouse.y)
                settingsWindow.endChipDrag(p.x, p.y)
            }

            Rectangle {
                id: dragGhost
                visible: settingsWindow.chipDragActive
                x: settingsWindow.chipDragX - settingsWindow.chipDragOffsetX
                y: settingsWindow.chipDragY - settingsWindow.chipDragOffsetY
                width: ghostText.implicitWidth + 20
                height: 30
                radius: height / 2
                color: Colors.pillActive
                border.color: Colors.mPrimary
                border.width: 1
                opacity: 0.9

                NText {
                    id: ghostText
                    anchors.centerIn: parent
                    text: settingsWindow.chipDragLabel
                    color: Colors.text
                    pointSize: Style.fontSizeS
                }
            }
        }
    }
}
