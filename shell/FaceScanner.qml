// Face recognition backend: runs howdy-next's native compare helper (or the mock
// stub) and reports the outcome. Logic only — no visuals, no unlock decisions.
// The caller owns both: it drives FacePlaque from the signals and decides when
// to unlock.
//
// TEARDOWN, and why every detail of it matters (learned the hard way — a wedged
// facetimehd that "does not even turn on" until the module is reloaded):
//
//   * The camera is held by howdy-compare, a GRANDchild (qs -> sudo -> timeout ->
//     howdy-compare). proc.signal() can only reach sudo. SIGKILL is not relayed by
//     anyone, so killing sudo with 9 orphans the process that holds the camera.
//   * SIGTERM *is* relayed by both sudo and timeout(1), and howdy-compare runs its
//     cleanup on it, so OpenCV releases the device. SIGKILL cannot be handled:
//     the device is torn down mid-capture and the driver is left streaming into
//     a queue nobody owns. TERM everywhere, KILL only as timeout(1)'s escalation.
//   * The ladder must fire inside-out, so the stage that CAN reach howdy-compare
//     always acts first: howdy-next exits within its configured scan window plus
//     camera startup < timeout(1) TERM (11 s) < timeout(1) KILL (13 s) < this
//     Timer (14 s). Invert it — a UI cap shorter than the kernel-side cap — and
//     the UI kill orphans the camera holder, which the escalation then SIGKILLs
//     mid-capture. That is exactly how the driver got wedged.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string user: Quickshell.env("USER") || ""
    // Last resort only: normally howdy exits on its own and timeout(1) is the
    // backstop. See the ladder above before shortening this.
    property int timeoutMs: 14000

    readonly property bool scanning: proc.running

    // "no-match"     — howdy-next exhausted its scan without a match (mapped from exit 11)
    // "too-dark"     — every frame was below howdy-next's dark threshold (exit 13)
    // "unavailable"  — the backend could not compare at all: camera busy or
    //                  wedged, missing model, bad config (exit 1 / 10 / 12 / …)
    // "timeout"      — the whole chain hung past timeoutMs
    signal succeeded()
    signal failed(string reason)

    // True while a teardown we initiated (abort or timeout) is in flight, so the
    // exited() it provokes does not turn into a signal nobody asked for.
    property bool _aborted: false
    // Dev mode is required, not just MUGLOCK_MOCK: a stray MUGLOCK_MOCK exported
    // in a real session would otherwise let the stub unlock the screen for free.
    readonly property bool _mock: (Quickshell.env("MUGLOCK_MOCK") || "") !== ""
        && Quickshell.env("MUGLOCK_DEV") === "1"

    function start(): void {
        if (proc.running)
            return;
        root._aborted = false;
        proc.command = root._mock
            // Dev-only path, and it assumes the repo layout: reaching outside the
            // config dir does not survive a symlinked install (see
            // scripts/test-symlinked-config.sh). Mock mode is never used there.
            ? ["bash", Quickshell.shellPath("../scripts/howdy-stub.sh")]
            : ["sudo", "-n", "/usr/bin/timeout", "--signal=TERM", "--kill-after=2", "11",
               "/usr/lib/howdy/howdy-compare", root.user];
        proc.running = true;
        timeout.restart();
    }

    // Stop scanning without reporting anything (used when the session unlocks by
    // password while a scan is still in flight). TERM, never KILL: it is relayed
    // down to howdy-compare, which releases the camera on its way out.
    function abort(): void {
        if (!proc.running)
            return;
        root._aborted = true;
        timeout.stop();
        proc.signal(15);
    }

    // howdy-next's howdy-compare exit codes. Anything unrecognized is treated as a
    // backend fault rather than a failed match: claiming "we looked and it
    // wasn't you" when the camera never opened sends the user hunting for
    // better lighting while the real problem is a dead device.
    function _reasonFor(exitCode: int): string {
        // 10 is "no face model known for this user". Verified the hard way:
        // howdy-next keeps models separately from howdy 2.x, so upgrading leaves
        // a machine with a working camera and no enrolled face — and reporting
        // that as a backend fault reads as "the camera is broken", which is
        // exactly the wrong place to send someone.
        if (exitCode === 10)
            return "no-model";
        // 11 is howdy-next's scan window expiring. It has no separate no-match
        // code, and from where the user sits the two are the same event: it
        // looked, the window ran out, nobody was recognized. Calling that a
        // timeout would blame the clock for an ordinary miss.
        if (exitCode === 11)
            return "no-match";
        if (exitCode === 13)
            return "too-dark";
        // timeout(1) reports 124 when it had to TERM the command, 137 when the
        // escalation SIGKILLed it. Both mean our own hard cap fired, which is a
        // timeout — not a broken camera. The scan timeout starts after camera open,
        // so it must leave startup headroom under the outer cap.
        if (exitCode === 124 || exitCode === 137)
            return "timeout";
        return "unavailable";
    }

    Process {
        id: proc
        onExited: (exitCode, exitStatus) => {
            timeout.stop();
            if (root._aborted)
                return;
            if (exitCode === 0)
                root.succeeded();
            else
                root.failed(root._reasonFor(exitCode));
        }
    }

    Timer {
        id: timeout
        interval: root.timeoutMs
        onTriggered: {
            root._aborted = true; // the teardown below must stay silent
            proc.signal(15); // relayed sudo -> timeout -> howdy-compare: clean release
            root.failed("timeout");
        }
    }
}
