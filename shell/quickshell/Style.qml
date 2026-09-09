pragma Singleton
import QtQuick
import Quickshell

// Design-token scale (font sizes/weights, radii, margins, borders, opacity,
// animation durations) - adapted from Noctalia's own Style.qml (MIT
// licensed, github.com/noctalia-dev/noctalia @ v4.7.7 - see README.md's
// "Third-party code" section) with everything coupled to their own
// dynamic-scaling settings stripped out: their version multiplies every
// value by a user-configurable scale ratio read from their own settings
// singleton, which Zaris has no equivalent of, so these are just the base
// values directly. Also dropped their bar-density/position-dependent sizing
// (mini/compact/comfortable/spacious, left/right/top/bottom) - Zaris's bar
// is a fixed single density and position, that whole axis doesn't apply.
//
// Existing QML files don't need to switch to this immediately - it's meant
// to make new/updated code more consistent than continuing to hand-pick
// pixel values per file, not a mandatory migration of what's already
// working.
Singleton {
    id: root

    // Scaled by DefaultsConfig.fontScale (Settings' Defaults tab "Font
    // size") - 1.0 at its default, so this is a no-op change from the
    // original flat values until the user actually picks a different size.
    readonly property real fontSizeXXS: 8 * DefaultsConfig.fontScale
    readonly property real fontSizeXS: 9 * DefaultsConfig.fontScale
    readonly property real fontSizeS: 10 * DefaultsConfig.fontScale
    readonly property real fontSizeM: 11 * DefaultsConfig.fontScale
    readonly property real fontSizeL: 13 * DefaultsConfig.fontScale
    readonly property real fontSizeXL: 16 * DefaultsConfig.fontScale
    readonly property real fontSizeXXL: 18 * DefaultsConfig.fontScale
    readonly property real fontSizeXXXL: 24 * DefaultsConfig.fontScale

    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // Container radii: major layout sections (sidebars, cards, content panels)
    readonly property int radiusXXXS: 3
    readonly property int radiusXXS: 4
    readonly property int radiusXS: 8
    readonly property int radiusS: 12
    readonly property int radiusM: 16
    readonly property int radiusL: 20

    // Input radii: interactive elements (buttons, toggles, text fields)
    readonly property int iRadiusXXXS: 3
    readonly property int iRadiusXXS: 4
    readonly property int iRadiusXS: 8
    readonly property int iRadiusS: 12
    readonly property int iRadiusM: 16
    readonly property int iRadiusL: 20

    readonly property int borderS: 1
    readonly property int borderM: 2
    readonly property int borderL: 3

    readonly property int marginXXXS: 1
    readonly property int marginXXS: 2
    readonly property int marginXS: 4
    readonly property int marginS: 6
    readonly property int marginM: 9
    readonly property int marginL: 13
    readonly property int marginXL: 18

    // Double margins, for proper container sizing only (e.g. height: id.implicitHeight + Style.margin2M)
    readonly property int margin2XXXS: marginXXXS * 2
    readonly property int margin2XXS: marginXXS * 2
    readonly property int margin2XS: marginXS * 2
    readonly property int margin2S: marginS * 2
    readonly property int margin2M: marginM * 2
    readonly property int margin2L: marginL * 2
    readonly property int margin2XL: marginXL * 2

    readonly property real opacityNone: 0.0
    readonly property real opacityLight: 0.25
    readonly property real opacityMedium: 0.5
    readonly property real opacityHeavy: 0.75
    readonly property real opacityAlmost: 0.95
    readonly property real opacityFull: 1.0

    // Animation duration (ms)
    readonly property int animationFaster: 75
    readonly property int animationFast: 150
    readonly property int animationNormal: 300
    readonly property int animationSlow: 450
    readonly property int animationSlowest: 750

    // Delays
    readonly property int tooltipDelay: 300
    readonly property int tooltipDelayLong: 1200
    readonly property int pillDelay: 500

    // Widgets base size
    readonly property real baseWidgetSize: 33
    readonly property real sliderWidth: 200

    // Pixel-perfect utility for centering content without subpixel positioning
    function pixelAlignCenter(containerSize, contentSize) {
        return Math.round((containerSize - contentSize) / 2)
    }

    // Ensures a number is always odd (rounds down to nearest odd)
    function toOdd(n) {
        return Math.floor(n / 2) * 2 + 1
    }

    // Ensures a number is always even (rounds down to nearest even)
    function toEven(n) {
        return Math.floor(n / 2) * 2
    }
}
