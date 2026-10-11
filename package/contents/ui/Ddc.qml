import QtQuick

import "mccs.js" as Mccs
import "profiles.js" as Profiles

// One monitor, controlled by running ddcutil through the shared Runner.
Item {
    id: ddc

    required property Runner runner
    // Stable identity from ddcutil detect: "MFG:Model:Serial" (plus connector if
    // there is no serial). Bus numbers change across replugs and resumes.
    required property string displayId
    required property string mfgModel
    property string name
    property string connector
    property int bus: -1

    // Resolved from the capabilities string on first refresh; see profiles.js.
    property var profile: null
    property string error: ""
    // VCP code -> { cur, max }
    property var values: ({})

    readonly property var activeLocks: profile ? profile.locks.filter(l => current(l.code, -1) === l.value) : []
    // One-line state for tooltips, e.g. "DisplayPort · Coding (Dark)".
    readonly property string status: error !== "" || !profile
        ? error
        : profile.summary.map(code => Profiles.describe(profile.controls[code], values[code])).filter(s => s).join(" · ")

    // A command failed; the bus may have changed.
    signal failed()

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

    function locked(code) {
        return activeLocks.some(l => l.codes.includes(code));
    }

    function refresh() {
        if (!profile) {
            loadProfile();
            return;
        }
        if (profile.readCodes.length > 0) {
            run("read", () => `ddcutil --bus ${bus} getvcp ${profile.readCodes.map(Mccs.hex).join(" ")} --terse`,
                { done: parseRead });
        }
        // ddcutil misreports undeclared codes inside a multi-code getvcp, so read each alone.
        for (const code of profile.soloReadCodes) {
            run(`read-${code}`, () => `ddcutil --bus ${bus} getvcp ${Mccs.hex(code)} --terse`,
                { done: parseRead, optional: true });
        }
    }

    // ddcutil caches capabilities on disk, so this is cheap after the first run.
    function loadProfile() {
        run("caps", () => `ddcutil --bus ${bus} capabilities --terse`, {
            done: stdout => {
                profile = Profiles.forDisplay(mfgModel, Mccs.parseCapabilities(stdout));
                refresh();
            },
        });
    }

    function set(code, value) {
        // Optimistic so the UI doesn't snap back while the write is in flight.
        const next = Object.assign({}, values);
        next[code] = { cur: value, max: values[code] ? values[code].max : 0 };
        values = next;
        // Vendor codes are often missing from the capabilities string.
        run(`write-${code}`, () => `ddcutil --bus ${bus} setvcp ${Mccs.hex(code)} ${value} --noverify --permit-unknown-feature`,
            { replace: true });
        settle.restart();
    }

    // Writes use --noverify for speed, so re-read once they stop; rejected
    // changes then snap back instead of showing a value the monitor never applied.
    Timer {
        id: settle
        interval: 1500
        onTriggered: ddc.refresh()
    }

    function run(key, command, options) {
        runner.enqueue({
            key: `${displayId}/${key}`,
            command: command,
            replace: !!options.replace,
            done: (exitCode, stdout, stderr) => {
                if (exitCode !== 0) {
                    if (!options.optional) {
                        error = (stderr || stdout).trim() || i18n("ddcutil exited with code %1", exitCode);
                        runner.cancel(`${displayId}/`);
                        failed();
                    }
                    return;
                }
                error = "";
                if (options.done) {
                    options.done(stdout);
                }
            },
        });
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
}
