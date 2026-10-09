import QtQuick
import org.kde.plasma.plasma5support as P5Support

import "features.js" as F

// Talks to the monitor by running ddcutil. Commands run one at a time because
// concurrent transactions on the same I2C bus corrupt each other.
Item {
    id: ddc

    property string modelMatch: "RD280U"
    property int busOverride: -1

    readonly property int bus: busOverride >= 0 ? busOverride : detectedBus
    readonly property bool busy: runningJob !== null
    property int detectedBus: -1
    property string monitorName: ""
    property string error: ""
    // VCP code -> { cur, max }
    property var values: ({})

    property var queue: []
    property var runningJob: null
    property string runningCommand: ""

    onModelMatchChanged: detectedBus = -1
    onBusOverrideChanged: refresh()

    function has(code) {
        return values[code] !== undefined;
    }

    function current(code, fallback) {
        const v = values[code];
        return v ? v.cur : fallback;
    }

    function maximum(code, fallback) {
        const v = values[code];
        return v && v.max > 0 ? v.max : fallback;
    }

    function refresh() {
        enqueue({ kind: "read" });
    }

    function set(code, value) {
        // Optimistic so the UI doesn't snap back while the write is in flight.
        const next = Object.assign({}, values);
        next[code] = { cur: value, max: values[code] ? values[code].max : 0 };
        values = next;
        enqueue({ kind: "write", code: code, value: value });
    }

    function enqueue(job) {
        if (job.kind === "write") {
            // Only the latest value per feature matters, e.g. while dragging a slider.
            queue = queue.filter(j => !(j.kind === "write" && j.code === job.code));
        } else if (queue.some(j => j.kind === job.kind)) {
            return;
        }
        queue = queue.concat([job]);
        pump();
    }

    function pump() {
        if (runningJob || queue.length === 0) {
            return;
        }
        if (bus < 0) {
            start({ kind: "detect" });
            return;
        }
        const job = queue[0];
        queue = queue.slice(1);
        start(job);
    }

    function start(job) {
        switch (job.kind) {
        case "detect":
            runningCommand = "ddcutil detect --terse";
            break;
        case "read":
            runningCommand = `ddcutil --bus ${bus} getvcp ${F.READ_CODES.map(F.hex).join(" ")} --terse`;
            break;
        case "write":
            runningCommand = `ddcutil --bus ${bus} setvcp ${F.hex(job.code)} ${job.value} --noverify`;
            break;
        }
        runningJob = job;
        executable.connectSource(runningCommand);
    }

    function finish(exitCode, stdout, stderr) {
        const job = runningJob;
        runningJob = null;
        runningCommand = "";

        if (job.kind === "detect") {
            parseDetect(stdout);
            if (detectedBus < 0) {
                error = i18n("No display matching “%1” found by ddcutil.", modelMatch);
                queue = [];
                return;
            }
        } else if (job.kind === "read") {
            parseRead(stdout);
        }

        if (exitCode !== 0) {
            error = (stderr || stdout).trim() || i18n("ddcutil exited with code %1", exitCode);
            if (busOverride < 0) {
                // Bus numbers can change across replugs and resumes; re-detect next time.
                detectedBus = -1;
            }
            queue = [];
            return;
        }
        if (job.kind !== "detect") {
            error = "";
        }
        pump();
    }

    function parseDetect(stdout) {
        detectedBus = -1;
        for (const block of stdout.split(/\n\s*\n/)) {
            if (block.startsWith("Invalid display")) {
                continue;
            }
            const busMatch = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
            const monitorMatch = block.match(/Monitor:\s*(.*)/);
            if (!busMatch || !monitorMatch) {
                continue;
            }
            const monitor = monitorMatch[1].trim();
            if (monitor.toLowerCase().includes(modelMatch.toLowerCase())) {
                detectedBus = parseInt(busMatch[1]);
                monitorName = monitor.split(":")[1] || monitor;
                return;
            }
        }
    }

    // Terse lines: "VCP 10 C 82 100", "VCP 14 CNC x00 x0b x00 x0b", "VCP 60 SNC x0f"
    function parseRead(stdout) {
        const next = Object.assign({}, values);
        for (const line of stdout.split("\n")) {
            const m = line.match(/^VCP ([0-9A-F]{2}) (\S+) ?(.*)$/);
            if (!m) {
                continue;
            }
            const code = parseInt(m[1], 16);
            const fields = m[3].split(" ").map(s => parseInt(s.replace(/^x/, ""), s.startsWith("x") ? 16 : 10));
            switch (m[2]) {
            case "C":
                next[code] = { cur: fields[0], max: fields[1] };
                break;
            case "CNC":
                // mh ml sh sl; for non-continuous features only sl is meaningful.
                next[code] = { cur: fields[3], max: 0 };
                break;
            case "SNC":
                next[code] = { cur: fields[0], max: 0 };
                break;
            }
        }
        values = next;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source === ddc.runningCommand) {
                ddc.finish(data["exit code"], data["stdout"], data["stderr"]);
            }
        }
    }
}
