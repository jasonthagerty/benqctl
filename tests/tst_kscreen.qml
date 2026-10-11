import QtQuick
import QtTest

import "../package/contents/ui/kscreen.js" as KScreen

DdcTestCase {
    name: "kscreen"

    // kscreen-two.json: recorded "kscreen-doctor -j" with the RD280U on DP-1
    // (primary, 170 %, HDR) and a laptop panel to its lower right.
    function outputs() {
        return KScreen.parseOutputs(fixture("kscreen-two.json"));
    }

    function test_parses_connected_outputs() {
        const o = outputs();
        compare(o.map(x => x.name), ["DP-1", "eDP-1"]);
        const dp = o[0];
        verify(dp.primary);
        compare(dp.priority, 1);
        compare([dp.pixelWidth, dp.pixelHeight], [3840, 2560]);
        compare([dp.width, dp.height], [2259, 1506], "logical size: pixels / scale, as System Settings arranges it");
        compare(dp.scale, 1.7);
        compare(Math.round(dp.refreshRate), 60);
        verify(dp.hdr);
        compare(dp.ddcCiAllowed, true);
        compare([o[1].x, o[1].y, o[1].priority, o[1].primary], [2259, 982, 2, false]);
        compare(o[1].ddcCiAllowed, undefined, "laptop panels don't report it");
    }

    function test_describe() {
        const o = outputs();
        compare(KScreen.describe(o[0], i18n), "DP-1 · Primary · 3840×2560 @ 60 Hz · 170% · HDR");
        compare(KScreen.describe(o[1], i18n), "eDP-1 · Priority 2 · 2560×1600 @ 60 Hz · 160%");
        compare(KScreen.describe(Object.assign({}, o[1], { enabled: false }), i18n), "eDP-1 · Disabled");
        compare(KScreen.describe(Object.assign({}, o[1], { rotation: 90 }), i18n),
                "eDP-1 · Priority 2 · 2560×1600 @ 60 Hz · 160% · Rotated 90°");
    }

    function test_rotation_swaps_logical_size() {
        const json = JSON.stringify({ outputs: [{
            name: "DP-2", connected: true, enabled: true, priority: 1, pos: { x: 0, y: 0 },
            size: { width: 2560, height: 1440 }, scale: 1, rotation: 2, currentModeId: "1", modes: [],
        }] });
        const o = KScreen.parseOutputs(json)[0];
        compare(o.rotation, 90);
        compare([o.width, o.height], [1440, 2560]);
    }

    function test_skips_disconnected_and_garbage() {
        compare(KScreen.parseOutputs(JSON.stringify({ outputs: [{ name: "HDMI-A-1", connected: false }] })), []);
        compare(KScreen.parseOutputs(""), []);
        compare(KScreen.parseOutputs("kscreen-doctor: command not found"), []);
        compare(KScreen.parseOutputs("{}"), []);
    }

    function test_bounds() {
        // eDP-1 is 2560×1600 at 160 %: 1600×1000 logical, at (2259, 982).
        compare(KScreen.bounds(outputs()), { x: 0, y: 0, width: 2259 + 1600, height: 982 + 1000 });
        compare(KScreen.bounds([]), { x: 0, y: 0, width: 0, height: 0 });
    }

    function test_output_for_known_monitor() {
        const o = outputs();
        const benq = { connector: "DP-1", mfgModel: "BNQ:BenQ RD280U" };
        // Qt's view of the screens, as Qt.application.screens reported it on this machine.
        const screens = [{ name: "DP-1", manufacturer: "BNQ", model: "BenQ RD280U" },
                         { name: "eDP-1", manufacturer: "Apple Computer Inc", model: "eDP-1-Color LCD" }];
        compare(KScreen.outputFor(benq, o, screens).name, "DP-1");
        compare(KScreen.outputFor(benq, o, []).name, "DP-1", "no Qt screen info: trust the connector");
        compare(KScreen.outputFor({ connector: "HDMI-A-1", mfgModel: "DEL:DELL U2723QE" }, o, screens), null, "not connected");
        compare(KScreen.outputFor({ connector: "DP-1", mfgModel: "DEL:DELL U2723QE" }, o, screens), null,
                "another monitor is on that connector now");
        compare(KScreen.outputFor({ connector: "DP-1", mfgModel: "XYZ:BenQ RD280U" }, o, screens).name, "DP-1",
                "model alone is enough");
    }
}
