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

    readonly property var categories: [
        { id: "general", label: "General", icon: "" },
        { id: "defaults", label: "Defaults", icon: "" },
        { id: "layout", label: "Layout", icon: "" },
        { id: "colors", label: "Colors", icon: "" },
        { id: "profile", label: "Profile", icon: "" },
        { id: "weather", label: "Weather", icon: "" },
        { id: "bar", label: "Bar", icon: "" },
        { id: "modules", label: "Modules", icon: "" },
        { id: "dock", label: "Dock", icon: "" }
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
                                    width: launcherIconRow.width - 170 - 24 - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: BarConfig.launcherIcon
                                    onEditingFinished: BarConfig.setLauncherIcon(text)
                                    onAccepted: BarConfig.setLauncherIcon(text)
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
                                    width: ccIconRow.width - 170 - 24 - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: BarConfig.controlCenterIcon
                                    onEditingFinished: BarConfig.setControlCenterIcon(text)
                                    onAccepted: BarConfig.setControlCenterIcon(text)
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

                        // ==================== Modules ====================
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: settingsWindow.activeCategory === "modules"

                            Row {
                                width: parent.width
                                height: 28

                                NText { text: "Module"; width: 170; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "Enabled"; width: 80; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "Screens"; width: 140; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                                NText { text: "In tray"; width: 80; color: Colors.textMuted; pointSize: Style.fontSizeS; font.weight: Style.fontWeightBold }
                            }

                            Repeater {
                                model: ModulesConfig.moduleIds

                                Row {
                                    id: row
                                    required property string modelData
                                    width: contentColumn.width
                                    height: 40

                                    readonly property var entry: ModulesConfig.configFile.adapter[modelData]

                                    NText {
                                        text: settingsWindow.moduleNames[row.modelData] || row.modelData
                                        width: 170
                                        color: Colors.text
                                        pointSize: Style.fontSizeM
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    ToggleSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: row.entry.enabled !== false
                                        onToggled: newChecked => ModulesConfig.setEnabled(row.modelData, newChecked)
                                    }

                                    Item { width: 36; height: 1 }

                                    NTabBar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        tabHeight: 22

                                        NTabButton {
                                            text: "All"
                                            pointSize: Style.fontSizeS
                                            checked: row.entry.screens === "all" || row.entry.screens === undefined
                                            onClicked: ModulesConfig.setScreens(row.modelData, "all")
                                        }

                                        NTabButton {
                                            text: "Primary"
                                            pointSize: Style.fontSizeS
                                            checked: row.entry.screens === "primary"
                                            onClicked: ModulesConfig.setScreens(row.modelData, "primary")
                                        }
                                    }

                                    ToggleSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: row.entry.tray === true
                                        onToggled: newChecked => ModulesConfig.setTray(row.modelData, newChecked)
                                    }
                                }
                            }

                            NText {
                                text: "\"Screens\" here only covers All / Primary - to pin a module to specific monitors by name, edit modules.json directly (\"screens\": [\"DisplayPort-1\"], matching `xrandr` output names)."
                                width: parent.width
                                wrapMode: Text.WordWrap
                                color: Colors.textMuted
                                pointSize: Style.fontSizeXS
                                topPadding: 10
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
                    }
                }
            }
        }
    }
}
