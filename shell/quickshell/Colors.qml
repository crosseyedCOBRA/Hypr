pragma Singleton
import QtQuick

// Shared palette so every part of the shell (bar, launcher, OSD, flyout,
// settings window) looks like one consistent thing rather than several.
// ~/.config/dunst/dunstrc and ~/.config/rofi/theme.rasi are themed to match
// these same values by hand -- they can't import this file, so keep them in
// sync manually if you change a color here.
QtObject {
    readonly property string bg: "#0c0b1a"
    readonly property string pill: "#1b204c"
    readonly property string pillActive: "#2d3a74"
    readonly property string text: "#e8e6f0"
    readonly property string textMuted: "#8890b5"
    readonly property string teal: "#4da4a6"
    readonly property string blue: "#5b7fd6"
    readonly property string purple: "#b882be"
    readonly property string coral: "#c55a63"
}
