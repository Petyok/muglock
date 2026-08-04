// Dev harness: shows LockContent in a normal window, without locking the
// session. Run: qs -p shell/DevPreview.qml
import Quickshell

ShellRoot {
    FloatingWindow {
        title: "muglock dev preview"
        implicitWidth: 1100
        implicitHeight: 700

        LockContent {
            anchors.fill: parent
            onUnlockRequested: console.log("MUGLOCK: unlockRequested")
            onKeyPressed: console.log("MUGLOCK: keyPressed")
        }
    }
}
