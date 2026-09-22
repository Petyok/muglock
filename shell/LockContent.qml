// One screen's lockscreen UI: gradient background, clock, date, a slot for the
// FaceID plaque, and the password fallback (system PAM stack, never howdy).
// Purely local: it knows nothing about WlSessionLock or the face scanner.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

Item {
    id: root

    // PAM accepted the password, or the owner of this item decided we are done.
    signal unlockRequested()
    // A "look at me again" gesture: a non-text key on an empty password field,
    // or a click on the plaque. Integration uses it to retry a failed scan.
    // Printable keys never fire it — those are someone typing a password.
    signal keyPressed()

    // Mount point for extra plaque-area content, if anything ever needs it.
    property alias plaqueSlot: plaqueHolder
    // Drives the mounted FacePlaque. shell.qml binds every screen's copy to its
    // single scanPhase, and to the scanner's user so the greeting always names
    // whoever howdy actually compared (both default to env USER).
    property alias scanPhase: plaque.phase
    property alias scanUser: plaque.user
    property alias scanShake: plaque.shakeSeq
    property alias scanReason: plaque.reason

    focus: true
    Component.onCompleted: field.forceActiveFocus()

    // Ticks once a second; both clock labels read it.
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Without a tracker the sink's audio properties never populate.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    PamContext {
        id: pam
        // The same service hyprlock uses. muglock never writes /etc/pam.d.
        config: "login"

        // Respond per *message*, never per responseRequired transition: the
        // property stays true between conversations, so a -Changed handler
        // fires exactly once and every later attempt deadlocks waiting for a
        // response that nothing sends (locking the user out of the password
        // path entirely).
        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(field.text);
        }
        onCompleted: result => {
            field.text = "";
            if (result === PamResult.Success)
                root.unlockRequested();
            else
                shakeAnim.restart();
        }
        onError: error => {
            field.text = "";
            shakeAnim.restart();
        }
    }

    // Current xkb layout as a short chip ("EN", "RU"). A password field with
    // hidden echo plus a silently wrong layout is exactly how a correct
    // password "doesn't work". Seeded by hyprctl, kept live by IPC events.
    property string kbLayout: ""
    function shortLayout(name) {
        return name.trim().split(" ")[0].slice(0, 2).toUpperCase();
    }

    Process {
        id: layoutProbe
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    for (const kb of keyboards) {
                        if (kb.main) {
                            root.kbLayout = root.shortLayout(kb.active_keymap);
                            return;
                        }
                    }
                } catch (e) {
                    // Not Hyprland or no hyprctl: the chip just stays hidden.
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",");
                root.kbLayout = root.shortLayout(parts[parts.length - 1]);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bg1 }
            GradientStop { position: 0.5; color: Theme.bg2 }
            GradientStop { position: 1.0; color: Theme.bg3 }
        }

        // The palette walks the blue channel through about 38 values across the
        // whole screen height, so in 8-bit colour a clean gradient can only be
        // ~24 px stripes — visible banding on the real display, not just in a
        // recording. A tiled neutral dither (half the pixels a touch lighter,
        // half a touch darker, mean zero) breaks the steps without shifting the
        // colour. Same reason hyprlock configs carry a `noise` value.
        Image {
            anchors.fill: parent
            source: Quickshell.shellPath("assets/noise.png")
            fillMode: Image.Tile
            smooth: false // no interpolation: the dither must stay pixel-exact
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.08
        spacing: 6

        Item {
            width: clock.width
            height: clock.height
            anchors.horizontalCenter: parent.horizontalCenter

            // Poor man's drop shadow: an accent copy behind the digits.
            Text {
                x: 0
                y: 4
                text: clock.text
                font: clock.font
                color: Theme.accent
                opacity: 0.30
            }
            Text {
                id: clock
                text: Qt.formatTime(root.now, "HH:mm")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 80
                font.bold: true
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                text: Qt.formatDate(root.now, "ddd dd MMM")
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }

            // Default sink mute state. The success chirp plays at whatever
            // volume the desktop left behind, so say up front whether it will
            // be heard; click toggles mute before the face is even scanned.
            Text {
                id: muteIcon
                readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
                visible: audio !== null
                anchors.verticalCenter: parent.verticalCenter
                text: audio?.muted ? "\u{F075F}" : "\u{F057E}"
                color: audio?.muted ? Theme.dim : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (muteIcon.audio) muteIcon.audio.muted = !muteIcon.audio.muted
                }
            }
        }

        Item { width: 1; height: 28 }

        // FacePlaque lands here (Task 5 visual, Task 9 wiring).
        Item {
            id: plaqueHolder
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            height: 80

            FacePlaque {
                id: plaque
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keyPressed() // click the plaque = rescan
            }
        }
    }

    Column {
        id: passwordArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        spacing: 10

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 48
            radius: height / 2
            color: "#14ffffff"
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.dim
            opacity: pam.active ? 0.6 : 1.0

            Behavior on border.color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Wrong password nudge.
            property real shakeX: 0
            transform: Translate { x: pill.shakeX }
            SequentialAnimation {
                id: shakeAnim
                loops: 2
                NumberAnimation { target: pill; property: "shakeX"; to: -9; duration: 45 }
                NumberAnimation { target: pill; property: "shakeX"; to: 9; duration: 90 }
                NumberAnimation { target: pill; property: "shakeX"; to: 0; duration: 45 }
            }

            // Layout chip: dim when EN, loud when anything else — the exact
            // trap this guards against is typing a password in the wrong layout.
            Text {
                id: layoutChip
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: root.kbLayout.length > 0
                text: root.kbLayout
                color: root.kbLayout === "EN" ? Theme.dim : Theme.failText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: root.kbLayout !== "EN"
            }

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: layoutChip.visible ? 46 : 18
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                readOnly: pam.active
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (pam.active) {
                            event.accepted = true;
                            return; // conversation already in flight
                        }
                        if (field.text.length > 0)
                            pam.start();
                        else
                            root.keyPressed(); // Enter on an empty field = scan again
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        // Panic hatch: abort a wedged PAM conversation and retype.
                        if (pam.active)
                            pam.abort();
                        field.text = "";
                        event.accepted = true;
                    }
                    // No other key triggers a rescan. Input methods (fcitx5)
                    // deliver composed printable keys with an empty event.text,
                    // so any "non-text key" heuristic here restarts the camera
                    // while the user is typing a password.
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: "Password"
                    color: Theme.dim
                    font: field.font
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: pam.message
            color: pam.messageIsError ? Theme.failText : Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 14
            opacity: text.length > 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
