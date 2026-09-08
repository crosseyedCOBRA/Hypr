pragma Singleton
import QtQuick

// Shared state for the "Pin to Dock" confirmation dialog (PinDialog.qml),
// opened via right-click on a Launcher result (Launcher.qml) or an existing
// dock icon (DockIcons.qml) - both just call open() rather than toggling
// DockConfig directly, so there's one themed, consistent confirmation UI
// instead of two different inline popups.
QtObject {
    id: root

    property bool visible: false
    property string appId: ""
    property string appName: ""
    property string appIcon: ""

    function open(id, name, icon) {
        if (!id)
            return
        root.appId = id
        root.appName = name || id
        root.appIcon = icon || ""
        root.visible = true
    }
}
