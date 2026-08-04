// Face recognition backend: runs howdy's compare.py (or the mock stub) and reports
// the outcome. Logic only — no visuals, no unlock decisions. The caller owns
// both: it drives FacePlaque from the signals and decides when to unlock.
//
// TEARDOWN, and why every detail of it matters (learned the hard way — a wedged
// facetimehd that "does not even turn on" until the module is reloaded):
//
//   * The camera is held by python3, a GRANDchild (qs -> sudo -> timeout ->
//     python3). proc.signal() can only reach sudo. SIGKILL is not relayed by
//     anyone, so killing sudo with 9 orphans the process that holds the camera.
//   * SIGTERM *is* relayed by both sudo and timeout(1), and Python runs its
//     cleanup on it, so OpenCV releases the device. SIGKILL cannot be handled:
//     the device is torn down mid-capture and the driver is left streaming into
//     a queue nobody owns. TERM everywhere, KILL only as timeout(1)'s escalation.
//   * The ladder must fire inside-out, so the stage that CAN reach python3 always
//     acts first: howdy's own video timeout (9 s, its config) < timeout(1) TERM
//     (11 s) < timeout(1) KILL (13 s) < this Timer (14 s). Invert it — a UI cap
//     shorter than the kernel-side cap — and the UI kill orphans the camera
//     holder, which the escalation then SIGKILLs mid-capture. That is exactly
//     how the driver got wedged.
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

    // "no-match"     — howdy looked and did not recognize the face (its exit 11)
    // "too-dark"     — every frame was below howdy's dark_threshold (exit 13)
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
            ? ["bash", Quickshell.shellPath("../scripts/howdy-stub.sh")]
            : ["sudo", "-n", "/usr/bin/timeout", "--signal=TERM", "--kill-after=2", "11",
               "/usr/bin/python3", "/usr/lib/security/howdy/compare.py", root.user];
        proc.running = true;
        timeout.restart();
    }

    // Stop scanning without reporting anything (used when the session unlocks by
    // password while a scan is still in flight). TERM, never KILL: it is relayed
    // down to python3, which then releases the camera on its way out.
    function abort(): void {
        if (!proc.running)
            return;
        root._aborted = true;
        timeout.stop();
        proc.signal(15);
    }

    // howdy's compare.py exit codes. Anything unrecognized is treated as a
    // backend fault rather than a failed match: claiming "we looked and it
    // wasn't you" when the camera never opened sends the user hunting for
    // better lighting while the real problem is a dead device.
    function _reasonFor(exitCode: int): string {
        if (exitCode === 11)
            return "no-match";
        if (exitCode === 13)
            return "too-dark";
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
            proc.signal(15); // relayed sudo -> timeout -> python3: clean release
            root.failed("timeout");
        }
    }
}
