import QtQuick
import Quickshell.Io

// Running kernel version, read once at startup.
Row {
    id: root

    property color textColor: "white"
    property string version: ""

    visible: root.version !== ""
    spacing: 4

    NText {
        text: "" // nf-fa-linux
        color: root.textColor
        pointSize: Style.fontSizeL
    }

    NText {
        text: root.version
        color: root.textColor
        pointSize: Style.fontSizeL
    }

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.version = this.text.trim()
        }
    }
}
