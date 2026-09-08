//@ pragma UseQApplication
import Quickshell

// UseQApplication above is required for StatusNotifierItem.display() (the tray
// context menu SystemTrayRow.qml uses) - it renders a native platform menu,
// which needs the heavier QApplication (Qt Widgets) init instead of the
// default leaner QGuiApplication. Confirmed via qs's own log: it fails
// outright with "Cannot display PlatformMenuEntry ... quickshell was not
// started in QApplication mode" without this. This pragma only takes effect
// on process startup, not a live config reload - quickshell needs a full
// restart after this changes.
//
// Entry point for the default Quickshell config (~/.config/quickshell/shell.qml).
// Composition root only - each piece of the shell lives in its own file so the
// bar (and anything else) can be added here later without touching Launcher.qml.
ShellRoot {
    Launcher {}
    Bar {}
    ControlCenter {}
    Settings {}
    OSD {}
    Dock {}
    PinDialog {}
    BluetoothPanel {}
    ClipboardHistoryPanel {}
    WallpaperPickerPanel {}
    CalendarFlyout {}
}
