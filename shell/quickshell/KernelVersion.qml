import QtQuick
import Quickshell.Io

// Running kernel version, read once at startup.
Row {
    id: root

    property color textColor: "white"
    property string version: ""

    visible: root.version !== ""
    spacing: 4

    Text {
        text: "" // nf-fa-linux
        color: root.textColor
        font.pixelSize: 13
    }

    Text {
        text: root.version
        color: root.textColor
        font.pixelSize: 13
    }

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.version = this.text.trim()
        }
    }
}
