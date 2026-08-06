// The FaceID plaque: a purely visual state machine. Set `phase` and it animates.
// It decides nothing — the scan is owned by FaceScanner and the unlock timing by
// shell.qml, so several plaques (one per screen) can bind to the same phase.
import QtQuick
import Quickshell

Item {
    id: root

    // "idle" | "scanning" | "success" | "failed"
    property string phase: "idle"
    property string user: Quickshell.env("USER") || ""
    // Failure class from FaceScanner: "no-match" | "too-dark" | "unavailable" |
    // "timeout". Only read while phase is "failed".
    property string reason: ""
    // Say what actually happened. "Didn't recognize you" for a camera that never
    // opened would send someone looking for better lighting for a dead device.
    readonly property string failedText:
        root.reason === "too-dark" ? "Too dark to see you — type your password"
        : root.reason === "unavailable" ? "Camera unavailable — type your password"
        : root.reason === "no-model" ? "No face enrolled — run: sudo howdy add"
        : root.reason === "timeout" ? "Face scan timed out — type your password"
        : "Didn't recognize you — type your password, or press Enter to retry"

    implicitWidth: 340
    implicitHeight: 80

    // Idle means "nothing to say" — the whole plaque fades out.
    opacity: root.phase === "idle" ? 0.0 : 1.0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Visuals only — the success chirp is owned by shell.qml, one per session
    // instead of one per screen.
    onPhaseChanged: if (root.phase === "success") springIn.restart()

    // Auto-retry pulse: shell.qml bumps this counter when a scan failed but
    // another attempt is coming — the plaque shakes its head and keeps looking.
    property int shakeSeq: 0
    onShakeSeqChanged: if (root.phase === "scanning") wobble.restart()

    SequentialAnimation {
        id: wobble
        NumberAnimation { target: root; property: "rotation"; to: -5; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "rotation"; to: 5; duration: 110; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "rotation"; to: -3; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "rotation"; to: 0; duration: 70; easing.type: Easing.OutQuad }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: iconSlot.width > 0 ? 14 : 0

        // Icon slot: face outline while scanning, green check on success.
        // No icon in the failed state — collapse instead of leaving a dead
        // 38 px hole that pushes the text off center.
        Item {
            id: iconSlot
            width: root.phase === "failed" ? 0 : 38
            height: 38
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // ---- scanning: pulsing face outline + scanline sweep ----
            Item {
                id: face
                anchors.fill: parent
                clip: true
                opacity: root.phase === "scanning" ? 1.0 : 0.0
                visible: opacity > 0.01
                scale: 1.0

                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 11
                    color: "transparent"
                    border.width: 2.5
                    border.color: Theme.accent
                }

                // Eyes.
                Rectangle {
                    x: 11; y: 13; width: 4; height: 4; radius: 2
                    color: Theme.accent
                }
                Rectangle {
                    x: 23; y: 13; width: 4; height: 4; radius: 2
                    color: Theme.accent
                }

                // Smile.
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Theme.accent;
                        ctx.lineWidth = 2;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2 + 1, 7, 0.25 * Math.PI, 0.75 * Math.PI, false);
                        ctx.stroke();
                    }
                }

                // Scanline: rides top to bottom, clipped to the face.
                Rectangle {
                    id: scanline
                    width: parent.width
                    height: 2
                    y: 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Theme.accent }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // One animation block for both the breathing and the sweep, so
                // they start and stop together with the scanning phase.
                ParallelAnimation {
                    running: root.phase === "scanning"
                    loops: Animation.Infinite

                    SequentialAnimation {
                        NumberAnimation { target: face; property: "scale"; from: 1.0; to: 1.08; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { target: face; property: "scale"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: scanline; property: "y"; from: 0; to: face.height - scanline.height; duration: 1300; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: scanline; property: "opacity"; from: 1.0; to: 0.0; duration: 300 }
                        PropertyAction { target: scanline; property: "y"; value: 0 }
                        PropertyAction { target: scanline; property: "opacity"; value: 1.0 }
                    }
                }
            }

            // ---- success: green ball with a white check, springing in ----
            Item {
                id: check
                anchors.fill: parent
                opacity: root.phase === "success" ? 1.0 : 0.0
                visible: opacity > 0.01
                scale: 1.0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.successBall
                }

                // Two strokes rotated into a tick.
                Item {
                    anchors.centerIn: parent
                    width: 20
                    height: 20

                    Rectangle {
                        x: 3; y: 11
                        width: 8; height: 2.5; radius: 1.25
                        color: "white"
                        transformOrigin: Item.Left
                        rotation: 45
                    }
                    Rectangle {
                        x: 8; y: 13
                        width: 13; height: 2.5; radius: 1.25
                        color: "white"
                        transformOrigin: Item.Left
                        rotation: -50
                    }
                }
            }

            SequentialAnimation {
                id: springIn
                NumberAnimation { target: check; property: "scale"; from: 0.3; to: 1.12; duration: 220; easing.type: Easing.OutBack }
                NumberAnimation { target: check; property: "scale"; to: 1.0; duration: 130; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Natural width up to the plaque's limit, so a short caption sits
            // centered next to the icon instead of leaving a fixed empty box.
            width: Math.min(implicitWidth, root.width - iconSlot.width - row.spacing)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 15
            text: root.phase === "scanning" ? "Looking for you…"
                : root.phase === "success" ? "Welcome back, " + root.user + "!"
                : root.phase === "failed" ? root.failedText
                : ""
            color: root.phase === "success" ? Theme.success
                : root.phase === "failed" ? Theme.dim
                : Theme.text

            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
