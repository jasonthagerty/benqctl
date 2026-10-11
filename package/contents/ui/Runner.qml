import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs ddcutil commands one at a time, across all monitors: concurrent
// transactions on the same I2C bus corrupt each other.
//
// A job is { key, command: () => string, done: (exitCode, stdout, stderr) => void,
// replace }. The command is built when the job starts, so it uses the bus a
// display has after any re-detection queued before it. A new job is dropped if
// one with the same key is already queued; with `replace` the queued one is
// dropped instead (only the latest write per feature matters, e.g. while
// dragging a slider).
Item {
    id: runner

    readonly property bool busy: running !== null
    property var queue: []
    property var running: null
    property string runningCommand: ""
    property int sequence: 0
    // How long a command may run before it is abandoned.
    property int timeout: 15000

    function enqueue(job) {
        if (job.replace) {
            queue = queue.filter(j => j.key !== job.key);
        } else if (queue.some(j => j.key === job.key)) {
            return;
        }
        queue = queue.concat([job]);
        pump();
    }

    // Drops queued jobs whose key starts with prefix.
    function cancel(prefix) {
        queue = queue.filter(j => !j.key.startsWith(prefix));
    }

    function pump() {
        if (running || queue.length === 0) {
            return;
        }
        const job = queue[0];
        queue = queue.slice(1);
        running = job;
        let command;
        try {
            command = job.command();
        } catch (e) {
            finish(-1, "", String(e));
            return;
        }
        // The engine runs this through a shell, which ignores the "#" comment.
        runningCommand = `${command} #${++sequence}`;
        executable.connectSource(runningCommand);
        watchdog.restart();
    }

    function finish(exitCode, stdout, stderr) {
        watchdog.stop();
        const job = running;
        running = null;
        runningCommand = "";
        try {
            job.done(exitCode, stdout || "", stderr || "");
        } finally {
            pump();
        }
    }

    // A wedged I2C transaction can leave ddcutil running indefinitely, which
    // would block the queue for good; give up on it and move on.
    Timer {
        id: watchdog
        interval: runner.timeout
        onTriggered: {
            executable.disconnectSource(runner.runningCommand);
            runner.finish(-1, "", i18n("ddcutil did not respond within %1 seconds.", watchdog.interval / 1000));
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source === runner.runningCommand) {
                runner.finish(data["exit code"], data["stdout"], data["stderr"]);
            }
        }
    }
}
