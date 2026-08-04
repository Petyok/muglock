// Face recognition backend: runs `howdy compare` (or the mock stub) and reports
// the outcome. Logic only — no visuals, no unlock decisions. The caller owns
// both: it drives FacePlaque from the signals and decides when to unlock.
//
// The camera is held only while the process runs, and never longer than
// timeoutMs (hard cap from the design: 10 s), after which the process is killed
// and the device released.
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
    readonly property bool _mock: (Quickshell.env("MUGLOCK_MOCK") || "") !== ""

    function start(): void {
        if (proc.running)
            return;
        root._aborted = false;
        proc.command = root._mock
            ? ["bash", Quickshell.shellPath("../scripts/howdy-stub.sh")]
            : ["sudo", "-n", "/usr/bin/howdy", "compare", root.user];
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
            proc.signal(9);
            root.failed("timeout");
        }
    }
}
