import QtQuick

import "ddcutil.js" as Ddcutil
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
                { done: parseRead, partial: true });
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
                // getvcp exits 1 if any one code fails ("VCP 94 ERR") but still
                // reports the rest; keep those rather than failing the read.
                if (exitCode !== 0 && !(options.partial && /^VCP [0-9A-F]{2} (?!ERR)/m.test(stdout))) {
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

    function parseRead(stdout) {
        values = Object.assign({}, values, Ddcutil.parseGetvcp(stdout));
    }
}
