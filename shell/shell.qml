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
    // "Still looking" feedback: howdy already re-evaluates every frame inside
    // one process (its internal video timeout IS the retry loop, with the
    // camera held open), so restarting the process for retries only pays the
    // ~2 s python+camera startup again. Instead one long scan runs, and the
    // plaque shakes its head every few seconds as a heartbeat. shakeSeq is a
    // declarative pulse — per-screen plaques bind to it just like scanPhase.
    property int shakeSeq: 0

    Timer {
        id: shakePulse
        interval: 3000
        repeat: true
        running: root.scanPhase === "scanning"
        onTriggered: root.shakeSeq++
    }
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
    // Overlays are mapped for the whole locked period, hidden beneath the
    // session-lock surface. By unlock time they are long painted, so the
    // handoff never races the compositor — no timing heuristics involved.
    property bool overlayArmed: false
    // Overlays that are actually mapped on screen. The lock is dropped only
    // once every screen's overlay is live — a timer here would be a guess
    // that loses on slow frames and flashes the bare desktop.
    property int overlaysLive: 0
    onOverlaysLiveChanged: {
        if (root.fading && !root.devMode && root.overlaysLive >= Quickshell.screens.length)
            swapFrame.restart();
    }

    Variants {
        model: ((root.overlayArmed || root.fading) && !root.devMode) ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            // Distinct namespace so compositors can exempt this layer from
            // their own fade animations (Hyprland: layerrule no_anim) —
            // otherwise the compositor fades the overlay IN while the lock
            // is already gone, which reads as a flash of bare desktop.
            WlrLayershell.namespace: "muglock-fade"
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

            onBackingWindowVisibleChanged: {
                root.overlaysLive += backingWindowVisible ? 1 : -1;
            }

            LockContent {
                anchors.fill: parent
                opacity: root.surfaceOpacity
                // Mirrors the real lock screen while hidden beneath it, then
                // freezes on the goodbye frame for the dissolve.
                scanPhase: root.fading ? "success" : root.scanPhase
                scanShake: root.shakeSeq
                scanUser: scanner.user
            }
        }
    }

    // One extra frame after the last overlay maps, so it has content painted
    // before the lock surface disappears beneath it.
    Timer {
        id: swapFrame
        interval: 32
        onTriggered: {
            console.log("MUGLOCK: swap -> unlock, overlaysLive=" + root.overlaysLive);
            fadeWatchdog.stop();
            sessionLock.locked = false;
            root.scanPhase = "idle";
            fadeAnim.restart();
        }
    }

    // The dissolve is decoration; the unlock is the contract. If the overlay
    // handoff has not happened shortly after an authenticated unlock started,
    // drop the animation and open the door.
    Timer {
        id: fadeWatchdog
        interval: 1500
        onTriggered: {
            console.log("MUGLOCK: fade watchdog fired, fading=" + root.fading + " locked=" + sessionLock.locked + " overlaysLive=" + root.overlaysLive);
            if (root.fading && sessionLock.locked)
                root.forceUnlock();
        }
    }

    // Unlock with no ceremony. Used when the pretty path wedges or when a
    // second authenticated unlock arrives mid-dissolve — animation state must
    // never be able to hold the session hostage.
    function forceUnlock(): void {
        console.log("MUGLOCK: forceUnlock");
        swapFrame.stop();
        fadeAnim.stop(); // onStopped resets fading + opacity
        fadeWatchdog.stop();
        root.fading = false;
        root.surfaceOpacity = 1;
        root.scanPhase = "idle";
        if (!root.devMode)
            sessionLock.locked = false;
    }

    NumberAnimation {
        id: fadeAnim
        target: root
        property: "surfaceOpacity"
        to: 0
        duration: 800
        easing.type: Easing.OutCubic
        onStopped: {
            console.log("MUGLOCK: fade done");
            root.fading = false;
            root.overlayArmed = false;
            root.surfaceOpacity = 1; // ready for the next lock
        }
    }

    // The ONLY place that starts dropping the lock. Reachable from the
    // post-success timer and from PAM success, nowhere else.
    function doUnlock(): void {
        console.log("MUGLOCK: doUnlock fading=" + root.fading + " overlaysLive=" + root.overlaysLive + " locked=" + sessionLock.locked);
        if (root.fading) {
            // A second authenticated unlock while a dissolve is (or claims to
            // be) in flight: the user has proven who they are, let them out now.
            root.forceUnlock();
            return;
        }
        scanner.abort(); // releases the camera right away, before the fade
        root.fading = true;
        if (root.devMode) {
            // No session lock to hand off in dev mode — dissolve the window content.
            root.scanPhase = "idle";
            fadeAnim.restart();
        } else {
            fadeWatchdog.restart();
            if (root.overlaysLive >= Quickshell.screens.length)
                swapFrame.restart(); // armed since lock() — already painted
            // else: onOverlaysLiveChanged completes the handoff once mapped
            // (cold-start edge), and the watchdog covers everything else.
        }
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
                scanShake: root.shakeSeq
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
                scanShake: root.shakeSeq
                scanUser: scanner.user
                onUnlockRequested: root.doUnlock()
                onKeyPressed: if (root.scanPhase === "failed") root.beginScan()
            }
        }
    }

    IpcHandler {
        target: "muglock"

        function lock(): void {
            console.log("MUGLOCK: ipc lock");
            swapFrame.stop(); // a lock during the dissolve wins over the unlock
            fadeAnim.stop(); // onStopped resets fading + opacity + armed
            fadeWatchdog.stop();
            root.fading = false;
            root.surfaceOpacity = 1;
            root.overlaysLive = 0; // recount: destroys send no farewell signal
            root.overlayArmed = true; // map overlays now, beneath the lock
            if (!root.devMode)
                sessionLock.locked = true;
            root.beginScan();
        }

        function wake(): void {
            console.log("MUGLOCK: ipc wake, locked=" + sessionLock.locked);
            if (sessionLock.locked || root.devMode)
                root.beginScan();
        }
    }
}
