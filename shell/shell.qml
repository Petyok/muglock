// muglock entry point. Owns three things and nothing else:
//   * the session lock (one surface per screen),
//   * the single scan phase every plaque binds to,
//   * the IPC surface hypridle talks to.
//
//   qs -p ~/.config/quickshell/muglock ipc call muglock lock   # engage the lock, start a scan
//   qs -p ~/.config/quickshell/muglock ipc call muglock wake   # re-scan after a wake, if locked
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
    onScanPhaseChanged: {
        console.log("MUGLOCK: phase", root.scanPhase);
        // Chirp lives here, not in FacePlaque: the plaque is instantiated once per
        // screen, so N monitors would mean N overlapping chirps. This root is one.
        if (root.scanPhase === "success" && !chirp.running)
            chirp.running = true;
    }

    Process {
        id: chirp
        command: ["paplay", Quickshell.shellPath("../assets/chirp.ogg")]
    }

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
        if (scanner.scanning) // start() would no-op; don't claim "scanning" twice
            return;
        root.scanPhase = "scanning";
        scanner.start();
    }

    // True fade-to-desktop. ext-session-lock hides the session while locked,
    // so fading the lock surface itself can only dissolve into the
    // compositor's blank fill. Instead: map an overlay layer drawing the
    // identical frame, drop the real lock behind it (pixel-identical swap the
    // eye can't see), then dissolve the overlay over the live desktop.
    property real surfaceOpacity: 1
    property bool fading: false

    Variants {
        model: (root.fading && !root.devMode) ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            mask: Region {} // empty input region: clicks fall through to the desktop
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            LockContent {
                anchors.fill: parent
                opacity: root.surfaceOpacity
                scanPhase: "success" // freeze the goodbye frame
                scanUser: scanner.user
            }
        }
    }

    SequentialAnimation {
        id: fadeOut
        ScriptAction {
            script: root.fading = true
        }
        PauseAnimation {
            duration: 60 // let the overlay map before the lock drops beneath it
        }
        ScriptAction {
            script: {
                if (!root.devMode)
                    sessionLock.locked = false;
                root.scanPhase = "idle";
            }
        }
        NumberAnimation {
            target: root
            property: "surfaceOpacity"
            to: 0
            duration: 800
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                root.fading = false;
                root.surfaceOpacity = 1; // ready for the next lock
            }
        }
    }

    // The ONLY place that starts dropping the lock. Reachable from the
    // post-success timer and from PAM success, nowhere else.
    function doUnlock(): void {
        if (fadeOut.running)
            return;
        scanner.abort(); // releases the camera right away, before the fade
        fadeOut.start();
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
                opacity: root.surfaceOpacity
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
            fadeOut.stop(); // a lock during the dissolve wins over the unlock
            root.fading = false;
            root.surfaceOpacity = 1;
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
