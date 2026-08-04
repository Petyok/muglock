// Face recognition backend: runs `howdy compare` (or the mock stub) and reports
// the outcome. Logic only — no visuals, no unlock decisions. The caller owns
// both: it drives FacePlaque from the signals and decides when to unlock.
//
// The camera is held only while the process runs. The hard cap is owned by
// timeout(1) inside the sudo command (12 s, SIGKILL): sudo cannot forward a
// signal to its child, so proc.signal() would only ever kill the sudo parent and
// leave howdy on the camera. The Timer below is the UI cap (timeoutMs, 10 s) — it
// reports "timeout" and best-effort stops the process, two seconds before the
// kernel-side kill it cannot lose a race with.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string user: Quickshell.env("USER") || ""
    property int timeoutMs: 10000

    readonly property bool scanning: proc.running

    signal succeeded()
    signal failed(string reason) // "no-match" | "timeout"

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
            : ["sudo", "-n", "/usr/bin/timeout", "--signal=KILL", "12", "/usr/bin/howdy", "compare", root.user];
        proc.running = true;
        timeout.restart();
    }

    // Stop scanning without reporting anything (used when the session unlocks by
    // password while a scan is still in flight).
    function abort(): void {
        if (!proc.running)
            return;
        root._aborted = true;
        timeout.stop();
        proc.signal(9);
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
                root.failed("no-match");
        }
    }

    Timer {
        id: timeout
        interval: root.timeoutMs
        onTriggered: {
            root._aborted = true; // the kill below must stay silent
            proc.signal(9); // best effort: reaps sudo, timeout(1) reaps howdy
            root.failed("timeout");
        }
    }
}
