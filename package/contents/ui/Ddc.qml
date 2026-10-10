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
    readonly property bool hdrActive: current(F.PICTURE_MODE, -1) === F.HDR_MODE
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

    function locked(code) {
        return hdrActive && F.HDR_LOCKED.includes(code);
    }

    function maximum(code, fallback) {
        const v = values[code];
        return v && v.max > 0 ? v.max : fallback;
    }

    function refresh() {
        enqueue({ kind: "read", codes: F.READ_CODES });
        // ddcutil misreports undeclared codes inside a multi-code getvcp, so read each alone.
        for (const code of F.SOLO_READ_CODES) {
            enqueue({ kind: "read", codes: [code], optional: true });
        }
    }

    function set(code, value) {
        // Optimistic so the UI doesn't snap back while the write is in flight.
        const next = Object.assign({}, values);
        next[code] = { cur: value, max: values[code] ? values[code].max : 0 };
        values = next;
        enqueue({ kind: "write", code: code, value: value });
        settle.restart();
    }

    // Writes use --noverify for speed, so re-read once they stop; rejected
    // changes then snap back instead of showing a value the monitor never applied.
    Timer {
        id: settle
        interval: 1500
        onTriggered: ddc.refresh()
    }

    function enqueue(job) {
        if (job.kind === "write") {
            // Only the latest value per feature matters, e.g. while dragging a slider.
            queue = queue.filter(j => !(j.kind === "write" && j.code === job.code));
        } else if (queue.some(j => j.kind === job.kind && String(j.codes) === String(job.codes))) {
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
            runningCommand = `ddcutil --bus ${bus} getvcp ${job.codes.map(F.hex).join(" ")} --terse`;
            break;
        case "write":
            // Several BenQ codes (e.g. KVM 0xE4) are missing from the capabilities string.
            runningCommand = `ddcutil --bus ${bus} setvcp ${F.hex(job.code)} ${job.value} --noverify --permit-unknown-feature`;
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

        if (exitCode !== 0 && job.optional) {
            pump();
            return;
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
                // mh ml sh sl; BenQ reports range-limited features' maximum in mh:ml.
                next[code] = { cur: fields[3], max: (fields[0] << 8) | fields[1] };
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
