import QtQuick

// Base text component used by the rest of the ported Noctalia widget
// library (adapted from Widgets/NText.qml, MIT licensed, v4.7.7 - see
// README.md's "Third-party code" section). Dropped their per-user font
// family/scale settings (Settings.data.ui.fontDefault etc.) - Zaris has no
// configurable font, every existing file just uses the system default -
// and their uiScaleRatio multiplier, which Style.qml already dropped for
// the same reason (no per-user dynamic scale setting here).
Text {
    id: root

    property bool richTextEnabled: false
    property bool markdownTextEnabled: false
    property real pointSize: Style.fontSizeM
    property var features: ({})

    opacity: enabled ? 1.0 : 0.6
    font.weight: Style.fontWeightMedium
    font.pointSize: Math.max(1, root.pointSize)
    font.features: root.features
    color: Colors.mOnSurface
    elide: Text.ElideRight
    wrapMode: Text.NoWrap
    verticalAlignment: Text.AlignVCenter

    textFormat: {
        if (root.richTextEnabled)
            return Text.RichText
        if (root.markdownTextEnabled)
            return Text.MarkdownText
        return Text.PlainText
    }
}
