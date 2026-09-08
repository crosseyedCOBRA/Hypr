import QtQuick

// Icon glyph text (adapted from Widgets/NIcon.qml, MIT licensed, v4.7.7 -
// see README.md's "Third-party code" section). Their version resolves a
// semantic icon *name* (e.g. "settings") through Icons.qml/IconsTabler.qml
// - a 6000+ entry name-to-glyph map bundled with their own custom Tabler
// icon font. Zaris has no such system and every existing file already
// embeds a raw Nerd Font glyph codepoint directly wherever an icon is
// needed (see Bar.qml/DockIcons.qml/etc.) - so `icon` here takes that same
// raw glyph string directly rather than introducing a parallel
// name-to-glyph abstraction with no backing data behind it. Whether to
// actually adopt their bundled icon font + name map is a separate,
// standalone decision (it means shipping a new font file, not just QML) -
// left for the coordinator/user rather than decided here.
Text {
    id: root

    property string icon: ""
    property real pointSize: Style.fontSizeL

    visible: icon !== ""
    text: icon
    font.pointSize: Math.max(1, root.pointSize)
    color: Colors.mOnSurface
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
