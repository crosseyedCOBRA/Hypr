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
    readonly property string red: "#d9556a"

    // Material Design 3 role aliases, adapted from Noctalia's Color.qml (MIT
    // licensed, github.com/noctalia-dev/noctalia @ v4.7.7 - see README.md's
    // "Third-party code" section) so ported Noctalia widgets that reference
    // `Color.mPrimary` etc. have something to bind to, without dragging in
    // their dynamic wallpaper-based color generation or live theme-switch
    // transition animations (Zaris's palette is a fixed set of constants,
    // never reassigned at runtime, so there's nothing to animate between).
    // Existing files keep using the flat names above directly - these are
    // purely additive, mapped onto them rather than replacing them:
    //   mPrimary/mSecondary/mTertiary - the three accent colors already in
    //     rotation across bar widgets (blue is the most-repeated accent, so
    //     it gets "primary"; teal and coral fill secondary/tertiary)
    //   mError - genuinely new; nothing above was a real alarm/danger red
    //     (coral reads more salmon than alarm), so `red` is a new base color
    //   mSurface/mSurfaceVariant - the two background tones already used
    //     for panels (bg) and cards/pills (pill)
    //   mOutline - textMuted, already used as the border color everywhere
    //   mHover - pillActive, already used for hover/active highlight fills
    //   mOn* - text or textMuted, whichever already reads correctly against
    //     that surface in the existing UI
    readonly property color mPrimary: blue
    readonly property color mOnPrimary: text
    readonly property color mSecondary: teal
    readonly property color mOnSecondary: text
    readonly property color mTertiary: coral
    readonly property color mOnTertiary: text
    readonly property color mError: red
    readonly property color mOnError: text
    readonly property color mSurface: bg
    readonly property color mOnSurface: text
    readonly property color mSurfaceVariant: pill
    readonly property color mOnSurfaceVariant: textMuted
    readonly property color mOutline: textMuted
    readonly property color mShadow: bg
    readonly property color mHover: pillActive
    readonly property color mOnHover: text

    // Resolves a user-facing "color key" (as used by e.g. a color-choice
    // picker) to an actual color/on-color pair - adapted from Noctalia's
    // same-named functions, dropping the "none" special-case tie to their
    // own capsule-color feature (callers here just treat an unrecognized
    // key as onSurface/surface, matching their own fallback branch).
    function resolveColorKey(key) {
        switch (key) {
        case "primary": return mPrimary
        case "secondary": return mSecondary
        case "tertiary": return mTertiary
        case "error": return mError
        default: return mOnSurface
        }
    }

    function resolveOnColorKey(key) {
        switch (key) {
        case "primary": return mOnPrimary
        case "secondary": return mOnSecondary
        case "tertiary": return mOnTertiary
        case "error": return mOnError
        default: return mSurface
        }
    }

    function resolveColorKeyOptional(key) {
        switch (key) {
        case "primary": return mPrimary
        case "secondary": return mSecondary
        case "tertiary": return mTertiary
        case "error": return mError
        default: return "transparent"
        }
    }

    readonly property var colorKeyModel: [
        { key: "none", name: "None" },
        { key: "primary", name: "Primary" },
        { key: "secondary", name: "Secondary" },
        { key: "tertiary", name: "Tertiary" },
        { key: "error", name: "Error" }
    ]
}
