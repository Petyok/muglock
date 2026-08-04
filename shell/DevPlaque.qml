// Dev harness for FacePlaque: cycles the phases forever in a normal window so
// the animations (pulse, scanline, spring) can be eyeballed. No chirp here — that
// one belongs to shell.qml so it stays one sound per success, not one per screen.
// Run: qs -p shell/DevPlaque.qml
import QtQuick
import Quickshell

ShellRoot {
    id: root

    // phase, how long to stay in it (ms)
    readonly property var cycle: [["idle", 1000], ["scanning", 3000], ["success", 2000], ["failed", 3000]]
    property int step: 0

    FloatingWindow {
        title: "muglock plaque dev"
        implicitWidth: 640
        implicitHeight: 300

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bg1 }
                GradientStop { position: 0.5; color: Theme.bg2 }
                GradientStop { position: 1.0; color: Theme.bg3 }
            }

            FacePlaque {
                anchors.centerIn: parent
                phase: root.cycle[root.step][0]
            }
        }
    }

    Timer {
        interval: root.cycle[root.step][1]
        running: true
        repeat: true
        onTriggered: {
            root.step = (root.step + 1) % root.cycle.length;
            console.log("MUGLOCK: phase", root.cycle[root.step][0]);
        }
    }
}
