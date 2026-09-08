import QtQuick

// The bar's status module row (tray, kernel, CPU/GPU, network, clipboard,
// notifications, wallpaper, battery, volume, stay-awake, night light, DND,
// Bluetooth) - its own file since Bar.qml now uses it identically in both
// of its layouts (BarConfig.layoutMode "statusbar" and "taskbar" - see
// Bar.qml's own layout comment) rather than duplicating this whole list
// between them. `barPanel` is passed in explicitly since this is a
// separate file rather than a nested Component closing over Bar.qml's own
// `panel` id.
Row {
    id: root

    required property var barPanel

    spacing: 14

    SystemTrayRow {
        window: root.barPanel
        visible: root.barPanel.isPrimary
        anchors.verticalCenter: parent.verticalCenter
    }

    KernelVersion {
        visible: ModulesConfig.showInBar("kernel", root.barPanel)
        textColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }

    CpuLoad {
        visible: ModulesConfig.showInBar("cpu", root.barPanel)
        textColor: Colors.coral
        anchors.verticalCenter: parent.verticalCenter
    }

    HwmonSensor {
        visible: ModulesConfig.showInBar("cpuTemp", root.barPanel)
        sensorLabel: "Tctl" // k10temp CPU die sensor -- verify with
                             // `grep . /sys/class/hwmon/hwmon*/temp*_label`
                             // and adjust if different
        iconGlyph: "\uf2c9"
        textColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }

    HwmonSensor {
        visible: ModulesConfig.showInBar("gpuTemp", root.barPanel)
        sensorLabel: "edge" // amdgpu GPU sensor -- same caveat as above
        iconGlyph: "\uf2c9"
        textColor: Colors.teal
        anchors.verticalCenter: parent.verticalCenter
    }

    NetworkStatus {
        visible: ModulesConfig.showInBar("network", root.barPanel)
        textColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }

    ClipboardIndicator {
        visible: ModulesConfig.showInBar("clipboard", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }

    NotificationIndicator {
        visible: ModulesConfig.showInBar("notifications", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.purple
        anchors.verticalCenter: parent.verticalCenter
    }

    WallpaperIndicator {
        visible: ModulesConfig.showInBar("wallpaper", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.teal
        anchors.verticalCenter: parent.verticalCenter
    }

    BatteryIndicator {
        visible: ModulesConfig.showInBar("battery", root.barPanel) && BatteryService.batteryPresent
        textColor: Colors.textMuted
        anchors.verticalCenter: parent.verticalCenter
    }

    VolumeControl {
        // Deliberately not gated by ModulesConfig.showInBar
        // ("volume", ...) - see VolumeControl.qml's own header comment.
        // Falls back to its own internal `visible: sink && sink.ready`
        // binding.
        textColor: Colors.purple
        anchors.verticalCenter: parent.verticalCenter
    }

    StayAwake {
        visible: ModulesConfig.showInBar("stayAwake", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.coral
        anchors.verticalCenter: parent.verticalCenter
    }

    NightLight {
        visible: ModulesConfig.showInBar("nightLight", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }

    Dnd {
        visible: ModulesConfig.showInBar("dnd", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.red
        anchors.verticalCenter: parent.verticalCenter
    }

    BluetoothIndicator {
        visible: ModulesConfig.showInBar("bluetooth", root.barPanel)
        textColor: Colors.textMuted
        activeColor: Colors.blue
        anchors.verticalCenter: parent.verticalCenter
    }
}
