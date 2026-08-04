// Dev harness for FaceScanner: run one scan, print the transition, quit.
// Needs no root and no camera — MUGLOCK_MOCK routes it to scripts/howdy-stub.sh,
// and MUGLOCK_DEV=1 is required for the mock to be honoured at all.
//   MUGLOCK_DEV=1 MUGLOCK_MOCK=ok   qs -p shell/DevScanner.qml  -> MUGLOCK: succeeded
//   MUGLOCK_DEV=1 MUGLOCK_MOCK=fail qs -p shell/DevScanner.qml  -> MUGLOCK: failed no-match
//   MUGLOCK_DEV=1 MUGLOCK_MOCK=slow qs -p shell/DevScanner.qml  -> MUGLOCK: failed timeout
import QtQuick
import Quickshell

ShellRoot {
    FaceScanner {
        // Harness-only override so the timeout case resolves in 3 s instead of
        // the production 14 s. FaceScanner's own default stays 10000.
        timeoutMs: 4000

        onSucceeded: {
            console.log("MUGLOCK: succeeded");
            Qt.quit();
        }
        onFailed: reason => {
            console.log("MUGLOCK: failed " + reason);
            Qt.quit();
        }

        Component.onCompleted: start()
    }
}
