import QtQuick
import QtTest

import "../package/contents/ui"
import "../package/contents/ui/mccs.js" as Mccs

// DisplayManager + Ddc against tests/bin/ddcutil, which answers from fixtures/:
// an RD280U on bus 5 (DP-1) and a generic Dell on bus 6 (HDMI-A-1).
DdcTestCase {
    id: testCase
    name: "displayManager"

    Component {
        id: managerComponent
        DisplayManager {
            preferredConnector: "HDMI-A-1"
        }
    }

    Component {
        id: runnerComponent
        Runner {}
    }

    property DisplayManager manager

    function init() {
        shell(': > "$FAKE_DDCUTIL_DIR/calls"; rm -f "$FAKE_DDCUTIL_DIR/detect"');
        manager = createTemporaryObject(managerComponent, testCase);
        manager.detect();
        tryVerify(() => manager.displays.length === 2, 5000);
        tryVerify(() => !manager.busy, 5000);
    }

    // Let queued reads finish so no ddcutil process outlives its test.
    function cleanup() {
        tryVerify(() => !manager.busy, 5000);
    }

    // Runs a shell command on a separate Runner and returns its stdout.
    function shell(command) {
        const runner = createTemporaryObject(runnerComponent, testCase);
        let out = null;
        runner.enqueue({ key: "shell", command: () => command, done: (code, stdout) => out = stdout });
        tryVerify(() => out !== null);
        return out;
    }

    function calls() {
        return shell('cat "$FAKE_DDCUTIL_DIR/calls"').trim().split("\n");
    }

    function display(connector) {
        return manager.displays.find(d => d.connector === connector);
    }

    function test_detects_displays_and_selects_preferred_screen() {
        compare(manager.displays.map(d => d.name), ["BenQ RD280U", "DELL U2723QE"]);
        compare(manager.selected.connector, "HDMI-A-1");
        compare(manager.error, "");
        compare(manager.forConnector("DP-1").name, "BenQ RD280U");
        compare(manager.forConnector("eDP-1").name, "BenQ RD280U", "unknown screens fall back to the first");
    }

    function test_vendor_profile_reads_all_values() {
        const benq = display("DP-1");
        compare(benq.profile.id, "benq-rd280u");
        compare(benq.error, "");
        compare(benq.current(Mccs.BRIGHTNESS, -1), 100);
        compare(benq.current(0xE4, -1), 2, "undeclared code read on its own");
        compare(benq.maximum(Mccs.VOLUME, 100), 50);
        compare(benq.status, "DisplayPort · HDR");
    }

    function test_undeclared_codes_use_separate_getvcp_calls() {
        const reads = calls().filter(c => c.startsWith("--bus 5 getvcp"));
        compare(reads, [
            "--bus 5 getvcp 60 DC 14 10 12 87 8A D1 D7 8D 62 --terse",
            "--bus 5 getvcp E4 --terse",
            "--bus 5 getvcp 19 --terse",
        ]);
    }

    function test_hdr_mode_locks_picture_controls() {
        const benq = display("DP-1");
        compare(benq.activeLocks.length, 1);
        verify(benq.locked(Mccs.BRIGHTNESS));
        verify(benq.locked(Mccs.DISPLAY_MODE));
        verify(!benq.locked(Mccs.SHARPNESS));
        verify(!display("HDMI-A-1").locked(Mccs.BRIGHTNESS), "generic profile has no locks");
    }

    function test_generic_profile_keeps_partial_reads() {
        // bus6 declares red gain (16) but answers "VCP 16 ERR", so getvcp exits 1.
        const dell = display("HDMI-A-1");
        compare(dell.profile.id, "generic");
        compare(dell.error, "");
        compare(dell.current(Mccs.BRIGHTNESS, -1), 75);
        verify(!dell.has(Mccs.RED_GAIN));
        compare(dell.status, "HDMI 1 · Brightness 75");
    }

    function test_set_writes_optimistically_then_rereads() {
        const benq = display("DP-1");
        benq.set(Mccs.SHARPNESS, 7);
        compare(benq.current(Mccs.SHARPNESS, -1), 7, "shown before the write finishes");
        tryVerify(() => calls().includes("--bus 5 setvcp 87 7 --noverify --permit-unknown-feature"));
        // The fake monitor ignores writes, like a real one rejecting a value,
        // so the settle re-read snaps the control back.
        tryVerify(() => benq.current(Mccs.SHARPNESS, -1) === 4, 5000);
    }

    function test_slider_writes_coalesce() {
        const benq = display("DP-1");
        benq.refresh(); // keep the runner busy so the writes queue up
        for (const v of [10, 20, 30, 40]) {
            benq.set(Mccs.BRIGHTNESS, v);
        }
        tryVerify(() => !manager.busy, 5000);
        const writes = calls().filter(c => c.includes("setvcp 10"));
        compare(writes, ["--bus 5 setvcp 10 40 --noverify --permit-unknown-feature"]);
    }

    function test_failed_display_triggers_redetect() {
        // A display whose bus no longer answers: its first command fails, the
        // manager re-detects, and the display disappears.
        manager.apply(manager.displays.map(d => ({
            id: d.displayId, mfgModel: d.mfgModel, name: d.name, connector: d.connector, bus: d.bus,
        })).concat([{ id: "XYZ:Gone:1", mfgModel: "XYZ:Gone", name: "Gone", connector: "DP-2", bus: 9 }]));
        compare(manager.displays.length, 3);
        tryVerify(() => manager.displays.length === 2, 5000);
        verify(!manager.displays.some(d => d.name === "Gone"));
        verify(calls().filter(c => c === "detect --terse").length >= 2);
    }

    function test_unresponsive_display_does_not_loop() {
        // Detected, but every command fails (e.g. monitor in standby).
        shell('echo detect-unresponsive.txt > "$FAKE_DDCUTIL_DIR/detect"');
        manager.detect();
        tryVerify(() => manager.displays.length === 3, 5000);
        const asleep = display("DP-2");
        tryVerify(() => asleep.error === "Display not found", 5000);
        wait(1000);
        verify(!manager.busy, "queue drained instead of retrying forever");
        const detects = calls().filter(c => c === "detect --terse").length;
        verify(detects <= 3, `${detects} detects`);
        compare(manager.displays.length, 3, "still listed; Retry or reopening tries again");
    }

    function test_redetect_keeps_display_objects() {
        const before = manager.displays.slice();
        manager.detect();
        tryVerify(() => !manager.busy, 5000);
        compare(manager.displays.length, 2);
        verify(manager.displays[0] === before[0] && manager.displays[1] === before[1],
               "identity is MFG:Model:Serial, so objects (and their values) survive");
    }
}
