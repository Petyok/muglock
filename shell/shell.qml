// muglock entry point. Owns three things and nothing else:
//   * the session lock (one surface per screen),
//   * the single scan phase every plaque binds to,
//   * the IPC surface hypridle talks to.
//
//   qs -c muglock ipc call muglock lock   # engage the lock, start a scan
//   qs -c muglock ipc call muglock wake   # re-scan after a wake, if locked
//
// MUGLOCK_DEV=1 keeps WlSessionLock instantiated but inert (`locked` is never
// set) and shows a normal window instead, so the whole flow can be exercised
// without locking the session or holding any privilege.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property bool devMode: Quickshell.env("MUGLOCK_DEV") === "1"

    // Single source of truth for ALL plaques: the lock surface is instantiated
    // once per screen, so each LockContent binds to this rather than being
    // reached into from here.
    property string scanPhase: "idle" // "idle" | "scanning" | "success" | "failed"
    onScanPhaseChanged: console.log("MUGLOCK: phase", root.scanPhase)

    FaceScanner { id: scanner }

    Connections {
        target: scanner

        function onSucceeded() {
            root.scanPhase = "success";
            unlockDelay.restart();
        }

        function onFailed(reason) {
            root.scanPhase = "failed";
        }
    }

    // Lets the success spring and the chirp play out before the screen vanishes.
    Timer {
        id: unlockDelay
        interval: 500
        onTriggered: root.doUnlock()
    }

    function beginScan(): void {
        root.scanPhase = "scanning";
        scanner.start();
    }

    // The ONLY place that drops the lock. Reachable from the post-success timer
    // and from PAM success, nowhere else.
    function doUnlock(): void {
        scanner.abort(); // releases the camera if a scan is still in flight
        root.scanPhase = "idle";
        if (!root.devMode)
            sessionLock.locked = false;
    }

    WlSessionLock {
        // NOT `lock`: that id would collide with IpcHandler's function lock().
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            color: Theme.bg1 // covers the frame before LockContent paints

            LockContent {
                anchors.fill: parent
                scanPhase: root.scanPhase
                scanUser: scanner.user
                onUnlockRequested: root.doUnlock() // PAM said yes
                onKeyPressed: if (root.scanPhase === "failed") root.beginScan()
            }
        }
    }

    // Dev mode: the same UI in an ordinary window, zero privileges, no locking.
    Loader {
        active: root.devMode
        sourceComponent: FloatingWindow {
            title: "muglock dev"
            implicitWidth: 1100
            implicitHeight: 700

            LockContent {
                anchors.fill: parent
                scanPhase: root.scanPhase
                scanUser: scanner.user
                onUnlockRequested: root.doUnlock()
                onKeyPressed: if (root.scanPhase === "failed") root.beginScan()
            }
        }
    }

    IpcHandler {
        target: "muglock"

        function lock(): void {
            if (!root.devMode)
                sessionLock.locked = true;
            root.beginScan();
        }

        function wake(): void {
            if (sessionLock.locked || root.devMode)
                root.beginScan();
        }
    }
}
