// One screen's lockscreen UI: gradient background, clock, date, a slot for the
// FaceID plaque, and the password fallback (system PAM stack, never howdy).
// Purely local: it knows nothing about WlSessionLock or the face scanner.
import QtQuick
import Quickshell.Services.Pam

Item {
    id: root

    // PAM accepted the password, or the owner of this item decided we are done.
    signal unlockRequested()
    // Any key that is not Enter. Integration uses it to retry a failed scan.
    signal keyPressed()

    // Mount point for extra plaque-area content, if anything ever needs it.
    property alias plaqueSlot: plaqueHolder
    // Drives the mounted FacePlaque. shell.qml binds every screen's copy to its
    // single scanPhase, and to the scanner's user so the greeting always names
    // whoever howdy actually compared (both default to env USER).
    property alias scanPhase: plaque.phase
    property alias scanUser: plaque.user

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

    PamContext {
        id: pam
        // Plain system stack. muglock never writes /etc/pam.d.
        config: "login"

        onResponseRequiredChanged: if (pam.responseRequired) pam.respond(field.text)
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlockRequested();
            } else {
                field.text = "";
                shakeAnim.restart();
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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "ddd dd MMM")
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 20
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

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                readOnly: pam.active
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (!pam.active && field.text.length > 0) pam.start();
                        event.accepted = true;
                    } else {
                        root.keyPressed();
                    }
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
