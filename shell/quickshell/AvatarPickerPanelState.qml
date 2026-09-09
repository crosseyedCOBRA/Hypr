pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared open/closed state for AvatarPickerPanel.qml, same pattern as
// SettingsState/ControlCenterState/PinDialogState/BluetoothPanelState/
// ClipboardHistoryPanelState/WallpaperPickerPanelState/
// NotificationHistoryPanelState.
//
// `version` is not just open/closed state - it's a cache-busting counter.
// ControlCenter.qml's avatar Image loads `~/.face` by a fixed path; QML's
// image cache keys on the URL string, not the file's actual contents, so
// overwriting `~/.face` in place (setAvatar() below) wouldn't be picked up
// by an already-running Control Center without something forcing a fresh
// load. Bumped once per successful set; ControlCenter.qml appends it to
// its own `~/.face` source URL as a query string, which is enough to make
// QML treat it as a different image and re-fetch even though it resolves
// to the exact same file.
//
// setAvatar()/setProc live here (rather than staying local to
// AvatarPickerPanel.qml, which is where this was originally written) so
// Settings.qml's own Profile-tab picture field can trigger the exact same
// cp-to-~/.face-plus-version-bump mechanism without duplicating it - two
// independent copies of this Process would risk drifting out of sync if
// one ever changed without the other.
QtObject {
    id: root

    property bool visible: false
    property int version: 0

    function setAvatar(path) {
        if (!path)
            return
        setProc.command = ["cp", path, Quickshell.env("HOME") + "/.face"]
        setProc.running = true
    }

    property Process setProc: Process {
        // The version bump (and, when the picker panel itself is the one
        // calling this, closing it) only happen here, after `cp` actually
        // finishes - bumping it right after setting `running: true` raced
        // the copy: Image would try to load the new source before the
        // file existed yet, land in Image.Error, and never retry on its
        // own once the file did show up a moment later (confirmed with a
        // debug status readout in Xephyr before this fix, back when this
        // logic was still local to AvatarPickerPanel.qml).
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.version = root.version + 1
                root.visible = false
            }
        }
    }
}
