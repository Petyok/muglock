// Colors, font and spacing shared by every muglock component.
// Parity with the author's hyprlock theme.
pragma Singleton
import QtQuick

QtObject {
    // Background gradient, top to bottom.
    readonly property color bg1: "#0b1526"
    readonly property color bg2: "#12233d"
    readonly property color bg3: "#0a1a2e"

    readonly property color accent: "#78d2ff"
    readonly property color text: "#ebf5ff"
    readonly property color dim: "#8aa6c4d8"
    readonly property color success: "#7dffa8"
    readonly property color successBall: "#2ecc71"
    readonly property color failText: "#ffb3a1"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
}
